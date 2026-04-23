//
//  WidgetDataProvider.swift
//  KeepInTouchWidget
//
//  Fetches Person + Group entities from the shared App Group Core Data
//  store and materializes them into lightweight OverduePerson DTOs for
//  the widget view.
//
//  Uses the Xcode-generated PersonEntity / GroupEntity classes (each
//  target compiles its own model and generates its own typed classes)
//  so schema renames break the build rather than silently returning
//  nil at runtime.
//

import CoreData
import Foundation

enum WidgetPersonStatus: Hashable {
    case overdue(daysOverdue: Int)
    case dueSoon(daysUntilDue: Int)
}

struct OverduePerson: Hashable {
    let id: UUID
    let displayName: String
    let initials: String
    let avatarColorHex: String
    let groupName: String
    let groupColorHex: String?
    let status: WidgetPersonStatus
}

enum WidgetDataProvider {

    static let maxFeaturedPeople = 3

    struct Snapshot {
        let overdueCount: Int
        let dueSoonCount: Int
        let featured: [OverduePerson]
        let hasTrackedPeople: Bool
        /// Raw AppSettings.theme string: "dark", "light", "system", or nil.
        let themeOverride: String?
    }

    static func loadSnapshot(now: Date = Date(), groupFilter: UUID? = nil) -> Snapshot {
        guard let context = WidgetCoreData.shared?.viewContext else {
            return Snapshot(overdueCount: 0, dueSoonCount: 0, featured: [], hasTrackedPeople: false, themeOverride: nil)
        }

        var result: Snapshot = .init(overdueCount: 0, dueSoonCount: 0, featured: [], hasTrackedPeople: false, themeOverride: nil)

        context.performAndWait {
            let hasTrackedPeople = countTrackedPeople(context: context) > 0
            let people = fetchTrackedPeople(context: context, groupFilter: groupFilter)
            let groupsByID = fetchGroupsByID(context: context)
            let themeOverride = fetchAppTheme(context: context)

            let atRisk = people
                .compactMap { person -> OverduePerson? in
                    guard
                        let id = person.id,
                        let displayName = person.displayName,
                        let initials = person.initials,
                        let avatarColor = person.avatarColor,
                        let groupId = person.groupId,
                        let group = groupsByID[groupId],
                        let groupName = group.name,
                        let status = statusFor(person: person, group: group, now: now)
                    else { return nil }

                    return OverduePerson(
                        id: id,
                        displayName: displayName,
                        initials: initials,
                        avatarColorHex: avatarColor,
                        groupName: groupName,
                        groupColorHex: group.colorHex,
                        status: status
                    )
                }
                .sorted(by: sortPriority)

            var overdueCount = 0
            var dueSoonCount = 0
            for person in atRisk {
                switch person.status {
                case .overdue: overdueCount += 1
                case .dueSoon: dueSoonCount += 1
                }
            }
            let featured = Array(atRisk.prefix(maxFeaturedPeople))

            result = Snapshot(
                overdueCount: overdueCount,
                dueSoonCount: dueSoonCount,
                featured: featured,
                hasTrackedPeople: hasTrackedPeople,
                themeOverride: themeOverride
            )
        }

        return result
    }

    /// Overdue people first (oldest overdue first), then due-soon
    /// (nearest due date first).
    private static func sortPriority(_ lhs: OverduePerson, _ rhs: OverduePerson) -> Bool {
        switch (lhs.status, rhs.status) {
        case (.overdue(let a), .overdue(let b)):
            return a > b
        case (.overdue, .dueSoon):
            return true
        case (.dueSoon, .overdue):
            return false
        case (.dueSoon(let a), .dueSoon(let b)):
            return a < b
        }
    }

    // MARK: - Core Data helpers

    private static func fetchAppTheme(context: NSManagedObjectContext) -> String? {
        let request: NSFetchRequest<AppSettingsEntity> = AppSettingsEntity.fetchRequest()
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first?.theme
    }

    /// Count-only fetch against every tracked non-demo person. Used
    /// only to distinguish "widget configured to an empty group" from
    /// "user has not added anyone yet" — and therefore ignores the
    /// group filter.
    private static func countTrackedPeople(context: NSManagedObjectContext) -> Int {
        let request: NSFetchRequest<PersonEntity> = PersonEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isTracked == YES AND isDemoData != YES")
        return (try? context.count(for: request)) ?? 0
    }

    private static func fetchTrackedPeople(
        context: NSManagedObjectContext,
        groupFilter: UUID?
    ) -> [PersonEntity] {
        let request: NSFetchRequest<PersonEntity> = PersonEntity.fetchRequest()
        var predicates: [NSPredicate] = [
            NSPredicate(format: "isTracked == YES"),
            NSPredicate(format: "isDemoData != YES"),
            NSPredicate(format: "isPaused != YES"),
        ]
        if let groupFilter {
            predicates.append(NSPredicate(format: "groupId == %@", groupFilter as CVarArg))
        }
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.fetchBatchSize = 50
        return (try? context.fetch(request)) ?? []
    }

    private static func fetchGroupsByID(context: NSManagedObjectContext) -> [UUID: GroupEntity] {
        let request: NSFetchRequest<GroupEntity> = GroupEntity.fetchRequest()
        request.fetchBatchSize = 50
        let groups = (try? context.fetch(request)) ?? []
        return Dictionary(uniqueKeysWithValues: groups.compactMap { group in
            group.id.map { ($0, group) }
        })
    }

    // MARK: - SLA

    /// Returns the person's at-risk status, or nil if on track.
    /// Respects snoozedUntil. Overdue = past the SLA. Due soon = within
    /// the group's warningDays window before the SLA.
    ///
    /// Known divergences from the app's FrequencyCalculator (acceptable
    /// for the widget's "glance" projection): ignores customBreachTime,
    /// customDueDate, and grace-period seeding. Users with custom
    /// cadences may see the widget disagree with the app by a day.
    private static func statusFor(
        person: PersonEntity,
        group: GroupEntity,
        now: Date
    ) -> WidgetPersonStatus? {
        if let snoozedUntil = person.snoozedUntil, snoozedUntil > now {
            return nil
        }

        guard let lastTouchAt = person.lastTouchAt else {
            return nil
        }

        let frequencyDays = Int(group.frequencyDays)
        guard frequencyDays > 0 else { return nil }
        let warningDays = Int(group.warningDays)

        let calendar = Calendar.current
        let fromDay = calendar.startOfDay(for: lastTouchAt)
        let toDay = calendar.startOfDay(for: now)
        let daysSinceLastTouch = calendar
            .dateComponents([.day], from: fromDay, to: toDay)
            .day ?? 0

        let delta = daysSinceLastTouch - frequencyDays
        if delta >= 0 {
            return .overdue(daysOverdue: delta)
        }
        if -delta <= warningDays {
            return .dueSoon(daysUntilDue: -delta)
        }
        return nil
    }
}
