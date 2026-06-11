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
}

/// The cohort of people whose birthday falls on the soonest upcoming day,
/// used by single-slot widget surfaces that can show only one name but want to
/// signal "+N more" when several share the day (#329).
struct BirthdayCohort: Equatable {
    /// The soonest birthday; its name is the one shown.
    let primary: BirthdaySummary
    /// Everyone on the same day as `primary` (including `primary`), sorted.
    let sameDay: [BirthdaySummary]

    /// People sharing the day beyond `primary` — the "+N" badge value.
    var additionalCount: Int { max(0, sameDay.count - 1) }
    /// Avatars to stack, capped at 3 for layout.
    var stackedAvatars: [BirthdaySummary] { Array(sameDay.prefix(3)) }

    /// Name line for single-slot surfaces: full name when alone, short name +
    /// "+N" when others share the day.
    var smallWidgetName: String {
        additionalCount > 0
            ? "\(primary.displayShortName) +\(additionalCount)"
            : primary.displayName
    }

    /// Tap target: the person when alone; the app overview when several share
    /// the day (a single-person link would be ambiguous).
    var tapURL: URL {
        additionalCount > 0 ? DeepLinkRoute.overdue.url() : DeepLinkRoute.person(primary.id).url()
    }

    /// Headline for the small Birthday widget: "Birthday tomorrow",
    /// "Birthdays today", "Birthday upcoming", etc. Plural when more than one
    /// person shares the soonest day; "upcoming" for anything past tomorrow.
    var birthdayHeadline: String {
        let noun = sameDay.count > 1 ? "Birthdays" : "Birthday"
        let when: String
        switch primary.daysUntil {
        case 0: when = "today"
        case 1: when = "tomorrow"
        default: when = "upcoming"
        }
        return "\(noun) \(when)"
    }
}

enum WidgetDataProvider {

    static let maxFeaturedPeople = 3

    /// Default lookahead for surfacing upcoming birthdays (#329).
    static let birthdayWindowDays = 7

    /// Upper bound on birthdays fetched per snapshot — larger than any single
    /// widget renders, so same-day cohort counts ("+N") stay accurate instead
    /// of being clipped by the display cap.
    static let birthdayFetchLimit = 10

    /// The soonest-day cohort from a `daysUntil`-ascending birthday list, or
    /// nil if empty. Same `daysUntil` == same calendar day.
    static func soonestBirthdayCohort(from birthdays: [BirthdaySummary]) -> BirthdayCohort? {
        guard let primary = birthdays.first else { return nil }
        let sameDay = birthdays.filter { $0.daysUntil == primary.daysUntil }
        return BirthdayCohort(primary: primary, sameDay: sameDay)
    }

    /// Groups a `daysUntil`-ascending birthday list into one cohort per
    /// distinct day, preserving order. Used by space-constrained surfaces that
    /// render one row per day ("Daniel +2 · tomorrow") rather than per person.
    static func birthdayCohortsByDay(from birthdays: [BirthdaySummary]) -> [BirthdayCohort] {
        var cohorts: [BirthdayCohort] = []
        var index = 0
        while index < birthdays.count {
            let day = birthdays[index].daysUntil
            let group = Array(birthdays[index...].prefix { $0.daysUntil == day })
            cohorts.append(BirthdayCohort(primary: group[0], sameDay: group))
            index += group.count
        }
        return cohorts
    }

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
        /// capped at `birthdayFetchLimit` (kept larger than any display cap so
        /// same-day "+N" counts stay accurate). Empty when `birthdaysFillWidget`
        /// is off. Used by the home widget's empty-space back-fill.
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
        groupFilter: UUID? = nil,
        showBirthdays: Bool = true
    ) -> Snapshot {
        context.performAndWait {
            let hasTrackedPeople = countTrackedPeople(context: context) > 0
            let people = fetchTrackedPeople(context: context, groupFilter: groupFilter)
            let groupsByID = fetchGroupsByID(context: context)
            let themeOverride = fetchAppTheme(context: context)
            // Skip the birthday fetch + cache read entirely when the widget
            // back-fill is off — nothing downstream reads it then.
            // Called inside this performAndWait, as upcomingBirthdays requires.
            let birthdays = showBirthdays
                ? upcomingBirthdays(context: context, now: now, within: birthdayWindowDays, limit: birthdayFetchLimit, groupFilter: groupFilter)
                : []

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

            return Snapshot(
                overdueCount: overdueCount,
                dueSoonCount: dueSoonCount,
                featured: featured,
                hasTrackedPeople: hasTrackedPeople,
                trackedCount: people.count,
                themeOverride: themeOverride,
                upcomingBirthdays: birthdays,
                birthdaysFillWidget: showBirthdays
            )
        }
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

            // Resolve the next occurrence once and derive daysUntil from it —
            // Birthday.daysUntil() would otherwise recompute nextOccurrence
            // internally, doubling the calendar-heavy work per person.
            let nextOccurrence = birthday.nextOccurrence(after: now, calendar: calendar)
            let daysUntil = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: nextOccurrence).day ?? 0
            guard daysUntil <= days else { return nil }

            return BirthdaySummary(
                id: id,
                displayName: displayName,
                nickname: person.nickname,
                initials: initials,
                avatarColorHex: avatarColor,
                daysUntil: daysUntil,
                nextOccurrence: nextOccurrence
            )
        }

        summaries.sort { lhs, rhs in
            lhs.daysUntil != rhs.daysUntil
                ? lhs.daysUntil < rhs.daysUntil
                : lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }

        return limit > 0 ? Array(summaries.prefix(limit)) : summaries
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
