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

struct OverduePerson: Hashable {
    let id: UUID
    let displayName: String
    let initials: String
    let avatarColorHex: String
    let groupColorHex: String?
    let daysOverdue: Int
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

        let overdue = people
            .compactMap { person -> OverduePerson? in
                guard
                    let id = person.value(forKey: "id") as? UUID,
                    let displayName = person.value(forKey: "displayName") as? String,
                    let initials = person.value(forKey: "initials") as? String,
                    let avatarColor = person.value(forKey: "avatarColor") as? String,
                    let groupId = person.value(forKey: "groupId") as? UUID,
                    let group = groupsByID[groupId]
                else { return nil }

                let daysOverdue = daysOverdueFor(person: person, group: group, now: now)
                guard daysOverdue > 0 else { return nil }

                return OverduePerson(
                    id: id,
                    displayName: displayName,
                    initials: initials,
                    avatarColorHex: avatarColor,
                    groupColorHex: group.value(forKey: "colorHex") as? String,
                    daysOverdue: daysOverdue
                )
            }
            .sorted { $0.daysOverdue > $1.daysOverdue }

        let featured = Array(overdue.prefix(maxFeaturedPeople))
        return Snapshot(
            overdueCount: overdue.count,
            featured: featured,
            hasTrackedPeople: !people.isEmpty
        )
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

    /// Returns days overdue (> 0) or 0 if the person is not overdue.
    /// Respects snoozedUntil — a snoozed-forward person is never overdue.
    private static func daysOverdueFor(
        person: NSManagedObject,
        group: NSManagedObject,
        now: Date
    ) -> Int {
        if let snoozedUntil = person.value(forKey: "snoozedUntil") as? Date,
           snoozedUntil > now {
            return 0
        }

        guard let lastTouchAt = person.value(forKey: "lastTouchAt") as? Date else {
            return 0
        }

        let frequencyDays = (group.value(forKey: "frequencyDays") as? Int64).map(Int.init) ?? 0
        guard frequencyDays > 0 else { return 0 }

        let calendar = Calendar.current
        let fromDay = calendar.startOfDay(for: lastTouchAt)
        let toDay = calendar.startOfDay(for: now)
        let daysSinceLastTouch = calendar
            .dateComponents([.day], from: fromDay, to: toDay)
            .day ?? 0

        let daysOverdue = daysSinceLastTouch - frequencyDays
        return max(daysOverdue, 0)
    }
}
