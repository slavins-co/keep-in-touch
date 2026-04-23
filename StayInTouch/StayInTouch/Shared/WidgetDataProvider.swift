//
//  WidgetDataProvider.swift
//  KeepInTouch (Shared — compiled into main app + widget extension)
//
//  Projects App Group Core Data entities into the lightweight DTOs
//  the widget renders. Testable parts (`snapshot`, `sortPriority`,
//  `statusFor`) live here so `StayInTouchTests` can exercise them via
//  `@testable import StayInTouch`. The widget-only `loadSnapshot`
//  wrapper — which reaches for `WidgetCoreData.shared` — lives in
//  `KeepInTouchWidget/WidgetDataProvider+Loader.swift`.
//
//  SLA uses the shared `FrequencyCalculator` (issue #284), so widget
//  and app agree on overdue / due-soon status for every person,
//  including `customDueDate` and grace-period (`groupAddedAt`) cases.
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

    /// Testable core. `loadSnapshot` in the widget target wraps this
    /// with `WidgetCoreData.shared?.viewContext`.
    static func snapshot(
        context: NSManagedObjectContext,
        now: Date = Date(),
        groupFilter: UUID? = nil
    ) -> Snapshot {
        var result = Snapshot(overdueCount: 0, dueSoonCount: 0, featured: [], hasTrackedPeople: false, themeOverride: nil)

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
    static func sortPriority(_ lhs: OverduePerson, _ rhs: OverduePerson) -> Bool {
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

    // MARK: - SLA (delegates to shared FrequencyCalculator)

    /// Lightweight adapter conforming to `FrequencyCalculatorPerson`,
    /// built from a `PersonEntity` read. Semantic renames preserved:
    /// entity `groupId` == domain `cadenceId`, entity `groupAddedAt` ==
    /// domain `cadenceAddedAt`.
    private struct WidgetSLAPerson: FrequencyCalculatorPerson {
        let isPaused: Bool
        let snoozedUntil: Date?
        let cadenceId: UUID
        let lastTouchAt: Date?
        let customDueDate: Date?
        let cadenceAddedAt: Date?
    }

    private struct WidgetSLACadence: FrequencyCalculatorCadence {
        let id: UUID
        let frequencyDays: Int
        let warningDays: Int
    }

    /// Returns the person's at-risk status, or nil if on track.
    /// Delegates to the shared `FrequencyCalculator` so the widget
    /// matches the main app for all SLA edge cases.
    static func statusFor(
        person: PersonEntity,
        group: GroupEntity,
        now: Date
    ) -> WidgetPersonStatus? {
        guard let groupId = group.id else { return nil }

        let slaPerson = WidgetSLAPerson(
            isPaused: person.isPaused,
            snoozedUntil: person.snoozedUntil,
            cadenceId: groupId,
            lastTouchAt: person.lastTouchAt,
            customDueDate: person.customDueDate,
            cadenceAddedAt: person.groupAddedAt
        )
        let slaCadence = WidgetSLACadence(
            id: groupId,
            frequencyDays: Int(group.frequencyDays),
            warningDays: Int(group.warningDays)
        )

        let calc = FrequencyCalculator(referenceDate: now)
        let cadences = [slaCadence]

        switch calc.status(for: slaPerson, in: cadences) {
        case .overdue:
            return .overdue(daysOverdue: calc.daysOverdue(for: slaPerson, in: cadences))
        case .dueSoon:
            guard let dueDate = calc.effectiveDueDate(for: slaPerson, in: cadences) else { return nil }
            let cal = Calendar.current
            let daysUntil = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: dueDate)).day ?? 0
            return .dueSoon(daysUntilDue: max(0, daysUntil))
        case .onTrack, .unknown:
            return nil
        }
    }
}
