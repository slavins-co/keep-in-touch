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

extension WidgetPersonStatus {
    /// Long-form, used by the medium home-screen widget.
    /// Example: "3 days overdue", "Due in 1 day", "Due today".
    var subtitle: String {
        switch self {
        case .overdue(let days):
            return "\(days) day\(days == 1 ? "" : "s") overdue"
        case .dueSoon(let days):
            return days == 0 ? "Due today" : "Due in \(days) day\(days == 1 ? "" : "s")"
        }
    }

    /// Compact form, used by small + accessory widgets.
    /// Example: "3d overdue", "Due in 1d", "Due today".
    var shortSubtitle: String {
        switch self {
        case .overdue(let days):
            return "\(days)d overdue"
        case .dueSoon(let days):
            return days == 0 ? "Due today" : "Due in \(days)d"
        }
    }
}

struct OverduePerson: Hashable {
    let id: UUID
    let displayName: String
    let nickname: String?
    let initials: String
    let avatarColorHex: String
    let groupName: String
    let groupColorHex: String?
    let status: WidgetPersonStatus
}

extension OverduePerson {
    /// Short display preference: nickname (when present) > first name > displayName.
    /// Used by accessory rectangular and inline widgets where space is constrained.
    var displayShortName: String {
        if let nick = nickname?.trimmingCharacters(in: .whitespacesAndNewlines), !nick.isEmpty {
            return nick
        }
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let first = trimmed.split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? trimmed : first
    }
}

/// Lightweight DTO for an upcoming birthday rendered by the widgets (#329).
struct BirthdaySummary: Hashable {
    let id: UUID
    let displayName: String
    let nickname: String?
    let initials: String
    let avatarColorHex: String
    /// Whole calendar days until the next occurrence (0 == today).
    let daysUntil: Int
    let nextOccurrence: Date
}

extension BirthdaySummary {
    /// Short display preference: nickname > first name > displayName.
    var displayShortName: String {
        if let nick = nickname?.trimmingCharacters(in: .whitespacesAndNewlines), !nick.isEmpty {
            return nick
        }
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let first = trimmed.split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? trimmed : first
    }

    /// "Today" / "Tomorrow" / "in N days".
    var countdownLabel: String {
        switch daysUntil {
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return "in \(daysUntil) days"
        }
    }

    /// Compact form for constrained surfaces: "today" / "tomorrow" / "Nd".
    var shortCountdownLabel: String {
        switch daysUntil {
        case 0: return "today"
        case 1: return "tomorrow"
        default: return "\(daysUntil)d"
        }
    }
}

enum WidgetDataProvider {

    static let maxFeaturedPeople = 3

    /// Default lookahead for surfacing upcoming birthdays (#329).
    static let birthdayWindowDays = 7

    struct Snapshot {
        let overdueCount: Int
        let dueSoonCount: Int
        let featured: [OverduePerson]
        let hasTrackedPeople: Bool
        /// Total tracked, non-paused, non-demo people in scope (after group
        /// filter). Used as the denominator for the accessory circular
        /// widget's gauge fill (`atRisk / trackedCount`).
        let trackedCount: Int
        /// Raw AppSettings.theme string: "dark", "light", "system", or nil.
        let themeOverride: String?
        /// Upcoming birthdays within `birthdayWindowDays`, soonest first,
        /// capped at `maxFeaturedPeople`. Used by the existing home widget's
        /// empty-space back-fill.
        let upcomingBirthdays: [BirthdaySummary]
        /// AppSettings flag gating whether the home widget back-fills empty
        /// space with birthdays. Defaults true when no settings row exists.
        let birthdaysFillWidget: Bool
    }

    /// Testable core. `loadSnapshot` in the widget target wraps this
    /// with `WidgetCoreData.shared?.viewContext`.
    static func snapshot(
        context: NSManagedObjectContext,
        now: Date = Date(),
        groupFilter: UUID? = nil
    ) -> Snapshot {
        var result = Snapshot(overdueCount: 0, dueSoonCount: 0, featured: [], hasTrackedPeople: false, trackedCount: 0, themeOverride: nil, upcomingBirthdays: [], birthdaysFillWidget: true)

        context.performAndWait {
            let hasTrackedPeople = countTrackedPeople(context: context) > 0
            let people = fetchTrackedPeople(context: context, groupFilter: groupFilter)
            let groupsByID = fetchGroupsByID(context: context)
            let themeOverride = fetchAppTheme(context: context)
            let birthdays = upcomingBirthdaysInContext(context: context, now: now, within: birthdayWindowDays, limit: maxFeaturedPeople, groupFilter: groupFilter)
            let birthdaysFillWidget = fetchBirthdaysFillWidget(context: context)

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
                        nickname: person.nickname,
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
                trackedCount: people.count,
                themeOverride: themeOverride,
                upcomingBirthdays: birthdays,
                birthdaysFillWidget: birthdaysFillWidget
            )
        }

        return result
    }

    /// The next local midnight strictly after `date`. Widget timelines emit
    /// an entry at this boundary so day-relative copy ("tomorrow" → "today",
    /// daysOverdue increments) rolls over without waiting on a periodic
    /// refresh (#329).
    static func nextLocalMidnight(after date: Date, calendar: Calendar = .current) -> Date {
        let startOfToday = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: startOfToday)
            ?? date.addingTimeInterval(24 * 60 * 60)
    }

    // MARK: - Upcoming birthdays (#329)

    /// Upcoming birthdays within `days`, soonest first (ties broken by name),
    /// capped at `limit` (pass `0` for no cap). Resolves each person's
    /// birthday from the stored `Person.birthday` first, falling back to the
    /// App Group `BirthdayCache` (contact-sourced, written by the app). Only
    /// people with `birthdayNotificationsEnabled == true` are considered.
    ///
    /// `cache` is injectable for testing; production reads `BirthdayCache`.
    /// Must be called inside the caller's `context.perform`/`performAndWait`.
    static func upcomingBirthdays(
        context: NSManagedObjectContext,
        now: Date = Date(),
        within days: Int = birthdayWindowDays,
        limit: Int = maxFeaturedPeople,
        groupFilter: UUID? = nil,
        calendar: Calendar = .current,
        cache: [UUID: Birthday]? = nil
    ) -> [BirthdaySummary] {
        let resolvedCache = cache ?? BirthdayCache.read()
        let people = fetchBirthdayCandidates(context: context, groupFilter: groupFilter)

        var summaries: [BirthdaySummary] = people.compactMap { person in
            guard
                let id = person.id,
                let displayName = person.displayName,
                let initials = person.initials,
                let avatarColor = person.avatarColor
            else { return nil }

            let birthday = person.birthday.flatMap(Birthday.from(jsonString:)) ?? resolvedCache[id]
            guard let birthday else { return nil }

            let daysUntil = birthday.daysUntil(from: now, calendar: calendar)
            guard daysUntil <= days else { return nil }

            return BirthdaySummary(
                id: id,
                displayName: displayName,
                nickname: person.nickname,
                initials: initials,
                avatarColorHex: avatarColor,
                daysUntil: daysUntil,
                nextOccurrence: birthday.nextOccurrence(after: now, calendar: calendar)
            )
        }

        summaries.sort { lhs, rhs in
            lhs.daysUntil != rhs.daysUntil
                ? lhs.daysUntil < rhs.daysUntil
                : lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }

        return limit > 0 ? Array(summaries.prefix(limit)) : summaries
    }

    /// Wrapper that opens its own `performAndWait` — for the dedicated
    /// Birthday widget timeline, which fetches birthdays independently of the
    /// overdue snapshot.
    static func birthdaysSnapshot(
        context: NSManagedObjectContext,
        now: Date = Date(),
        within days: Int = birthdayWindowDays,
        limit: Int = 5
    ) -> [BirthdaySummary] {
        var result: [BirthdaySummary] = []
        context.performAndWait {
            result = upcomingBirthdays(context: context, now: now, within: days, limit: limit)
        }
        return result
    }

    /// Internal variant used inside `snapshot()`'s existing `performAndWait`.
    private static func upcomingBirthdaysInContext(
        context: NSManagedObjectContext,
        now: Date,
        within days: Int,
        limit: Int,
        groupFilter: UUID?
    ) -> [BirthdaySummary] {
        upcomingBirthdays(context: context, now: now, within: days, limit: limit, groupFilter: groupFilter)
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

    /// Internal accessor for the raw theme override, used by the dedicated
    /// Birthday widget loader so it can apply the same app-theme treatment
    /// as the overdue widget. Must be called inside `context.perform`.
    static func themeOverride(context: NSManagedObjectContext) -> String? {
        fetchAppTheme(context: context)
    }

    /// Reads the birthdays-fill-widget flag. Defaults to `true` when no
    /// settings row exists (matches the model's `defaultValueString="YES"`).
    private static func fetchBirthdaysFillWidget(context: NSManagedObjectContext) -> Bool {
        let request: NSFetchRequest<AppSettingsEntity> = AppSettingsEntity.fetchRequest()
        request.fetchLimit = 1
        guard let settings = (try? context.fetch(request))?.first else { return true }
        return settings.birthdaysFillWidget
    }

    /// Tracked, non-demo people who opted into birthday surfacing. Paused and
    /// snoozed people are still included — a birthday is a birthday; the
    /// snooze/pause distinction governs SLA reminders, not birthdays. When a
    /// `groupFilter` is set (group-scoped widget), birthdays are scoped to the
    /// same group as the overdue list so the two surfaces stay consistent.
    private static func fetchBirthdayCandidates(
        context: NSManagedObjectContext,
        groupFilter: UUID?
    ) -> [PersonEntity] {
        let request: NSFetchRequest<PersonEntity> = PersonEntity.fetchRequest()
        var predicates: [NSPredicate] = [
            NSPredicate(format: "isTracked == YES"),
            NSPredicate(format: "isDemoData != YES"),
            NSPredicate(format: "birthdayNotificationsEnabled == YES"),
        ]
        if let groupFilter {
            predicates.append(NSPredicate(format: "groupId == %@", groupFilter as CVarArg))
        }
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.fetchBatchSize = 50
        return (try? context.fetch(request)) ?? []
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
            guard let daysUntil = calc.daysUntilDue(for: slaPerson, in: cadences) else { return nil }
            return .dueSoon(daysUntilDue: max(0, daysUntil))
        case .onTrack, .unknown:
            return nil
        }
    }
}
