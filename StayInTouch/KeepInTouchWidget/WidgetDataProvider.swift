//
//  WidgetDataProvider.swift
//  KeepInTouchWidget
//
//  Fetches Person + Group entities from the shared App Group Core Data
//  store and materializes them into lightweight OverduePerson DTOs for
//  the widget view.
//
//  Self-contained: no dependency on the main app's domain types or
//  FrequencyCalculator. The SLA rule here is intentionally simple and
//  matches the app's widget contract — not its full nuanced calc
//  (which handles customBreachTime, customDueDate, grace-period seeding,
//  etc.). The widget renders the "who is overdue right now?" projection
//  that matters for a glance.
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

    /// Maximum number of people surfaced in a single entry payload.
    /// The medium widget renders up to 3; keeping the DTO list bounded
    /// stays inside the extension's memory budget (30 MB).
    static let maxFeaturedPeople = 3

    struct Snapshot {
        let overdueCount: Int
        let featured: [OverduePerson]
        let hasTrackedPeople: Bool
    }

    static func loadSnapshot(now: Date = Date(), groupFilter: UUID? = nil) -> Snapshot {
        guard let context = WidgetCoreData.shared?.viewContext else {
            return Snapshot(overdueCount: 0, featured: [], hasTrackedPeople: false)
        }

        let people = fetchTrackedPeople(context: context, groupFilter: groupFilter)
        let groupsByID = fetchGroupsByID(context: context)

        let atRisk = people
            .compactMap { person -> OverduePerson? in
                guard
                    let id = person.value(forKey: "id") as? UUID,
                    let displayName = person.value(forKey: "displayName") as? String,
                    let initials = person.value(forKey: "initials") as? String,
                    let avatarColor = person.value(forKey: "avatarColor") as? String,
                    let groupId = person.value(forKey: "groupId") as? UUID,
                    let group = groupsByID[groupId],
                    let groupName = group.value(forKey: "name") as? String,
                    let status = statusFor(person: person, group: group, now: now)
                else { return nil }

                return OverduePerson(
                    id: id,
                    displayName: displayName,
                    initials: initials,
                    avatarColorHex: avatarColor,
                    groupName: groupName,
                    groupColorHex: group.value(forKey: "colorHex") as? String,
                    status: status
                )
            }
            .sorted(by: sortPriority)

        let overdueCount = atRisk.filter { if case .overdue = $0.status { return true } else { return false } }.count
        let featured = Array(atRisk.prefix(maxFeaturedPeople))
        return Snapshot(
            overdueCount: overdueCount,
            featured: featured,
            hasTrackedPeople: !people.isEmpty
        )
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

    private static func fetchTrackedPeople(
        context: NSManagedObjectContext,
        groupFilter: UUID?
    ) -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Person")
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

    private static func fetchGroupsByID(context: NSManagedObjectContext) -> [UUID: NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Group")
        request.fetchBatchSize = 50
        let groups = (try? context.fetch(request)) ?? []
        return Dictionary(uniqueKeysWithValues: groups.compactMap { group in
            (group.value(forKey: "id") as? UUID).map { ($0, group) }
        })
    }

    // MARK: - SLA

    /// Returns the person's at-risk status, or nil if on track (skipped
    /// from the widget). Respects snoozedUntil. Overdue = past the SLA.
    /// Due soon = within the group's warningDays window before the SLA.
    private static func statusFor(
        person: NSManagedObject,
        group: NSManagedObject,
        now: Date
    ) -> WidgetPersonStatus? {
        if let snoozedUntil = person.value(forKey: "snoozedUntil") as? Date,
           snoozedUntil > now {
            return nil
        }

        guard let lastTouchAt = person.value(forKey: "lastTouchAt") as? Date else {
            return nil
        }

        let frequencyDays = (group.value(forKey: "frequencyDays") as? Int64).map(Int.init) ?? 0
        guard frequencyDays > 0 else { return nil }
        let warningDays = (group.value(forKey: "warningDays") as? Int64).map(Int.init) ?? 0

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
