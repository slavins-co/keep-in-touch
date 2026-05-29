//
//  WidgetDataProviderTests.swift
//  StayInTouchTests
//
//  Covers the widget-only orchestration that `FrequencyCalculatorTests`
//  doesn't reach: `sortPriority` ordering, `snapshot` assembly (counts,
//  featured prefix, tracked-detection semantics), and parity with the
//  shared `FrequencyCalculator` for customDueDate + grace-period cases.
//

import CoreData
import XCTest
@testable import StayInTouch

final class WidgetDataProviderTests: XCTestCase {

    private var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        context = CoreDataTestStack().container.viewContext
    }

    // MARK: - sortPriority

    func testSortPriority_overdueBeforeDueSoon() {
        let overdue = makeOverduePerson(name: "A", status: .overdue(daysOverdue: 1))
        let dueSoon = makeOverduePerson(name: "B", status: .dueSoon(daysUntilDue: 2))

        XCTAssertTrue(WidgetDataProvider.sortPriority(overdue, dueSoon))
        XCTAssertFalse(WidgetDataProvider.sortPriority(dueSoon, overdue))
    }

    func testSortPriority_overdueOrdering_oldestFirst() {
        let threeDays = makeOverduePerson(name: "A", status: .overdue(daysOverdue: 3))
        let oneDay = makeOverduePerson(name: "B", status: .overdue(daysOverdue: 1))

        let sorted = [oneDay, threeDays].sorted(by: WidgetDataProvider.sortPriority)
        XCTAssertEqual(sorted.map(\.displayName), ["A", "B"], "Oldest overdue (3d) should sort first")
    }

    func testSortPriority_dueSoonOrdering_soonestFirst() {
        let threeDays = makeOverduePerson(name: "A", status: .dueSoon(daysUntilDue: 3))
        let oneDay = makeOverduePerson(name: "B", status: .dueSoon(daysUntilDue: 1))

        let sorted = [threeDays, oneDay].sorted(by: WidgetDataProvider.sortPriority)
        XCTAssertEqual(sorted.map(\.displayName), ["B", "A"], "Soonest due (1d) should sort first")
    }

    func testSortPriority_fullOrdering() {
        let list = [
            makeOverduePerson(name: "dueSoon3", status: .dueSoon(daysUntilDue: 3)),
            makeOverduePerson(name: "overdue1", status: .overdue(daysOverdue: 1)),
            makeOverduePerson(name: "dueSoon1", status: .dueSoon(daysUntilDue: 1)),
            makeOverduePerson(name: "overdue5", status: .overdue(daysOverdue: 5)),
        ]

        let sorted = list.sorted(by: WidgetDataProvider.sortPriority)
        XCTAssertEqual(sorted.map(\.displayName), ["overdue5", "overdue1", "dueSoon1", "dueSoon3"])
    }

    // MARK: - snapshot

    func testSnapshot_emptyStore() {
        let snap = WidgetDataProvider.snapshot(context: context)
        XCTAssertFalse(snap.hasTrackedPeople)
        XCTAssertEqual(snap.overdueCount, 0)
        XCTAssertEqual(snap.dueSoonCount, 0)
        XCTAssertTrue(snap.featured.isEmpty)
        XCTAssertNil(snap.themeOverride)
    }

    func testSnapshot_onlyOnTrackPeople() {
        let cadenceId = UUID()
        _ = seedGroup(id: cadenceId, frequencyDays: 30, warningDays: 3)
        _ = seedPerson(name: "Alice", cadenceId: cadenceId, lastTouchAt: daysAgo(1))

        let snap = WidgetDataProvider.snapshot(context: context)
        XCTAssertTrue(snap.hasTrackedPeople)
        XCTAssertEqual(snap.overdueCount, 0)
        XCTAssertEqual(snap.dueSoonCount, 0)
        XCTAssertTrue(snap.featured.isEmpty)
    }

    func testSnapshot_countsAndFeaturedPrefix() {
        let cadenceId = UUID()
        _ = seedGroup(id: cadenceId, frequencyDays: 10, warningDays: 2)

        // 5 overdue
        for i in 0..<5 {
            _ = seedPerson(name: "Over\(i)", cadenceId: cadenceId, lastTouchAt: daysAgo(20 + i))
        }
        // 2 due-soon (within 2 warning days, last touch 9d ago on a 10d cadence → 1 day until due)
        for i in 0..<2 {
            _ = seedPerson(name: "Soon\(i)", cadenceId: cadenceId, lastTouchAt: daysAgo(9))
        }
        // 3 on-track
        for i in 0..<3 {
            _ = seedPerson(name: "OK\(i)", cadenceId: cadenceId, lastTouchAt: daysAgo(1))
        }

        let snap = WidgetDataProvider.snapshot(context: context)
        XCTAssertTrue(snap.hasTrackedPeople)
        XCTAssertEqual(snap.overdueCount, 5)
        XCTAssertEqual(snap.dueSoonCount, 2)
        XCTAssertEqual(snap.featured.count, WidgetDataProvider.maxFeaturedPeople)
        // Featured should be the three most overdue (lastTouch 24d / 23d / 22d ago on 10d cadence → 14 / 13 / 12 days overdue).
        if case .overdue(let days) = snap.featured.first?.status {
            XCTAssertGreaterThanOrEqual(days, 12)
        } else {
            XCTFail("Featured[0] should be overdue")
        }
    }

    func testSnapshot_groupFilter_narrowsFeaturedButTracksGlobalCount() {
        let cadenceA = UUID()
        let cadenceB = UUID()
        _ = seedGroup(id: cadenceA, frequencyDays: 10, warningDays: 2)
        _ = seedGroup(id: cadenceB, frequencyDays: 10, warningDays: 2)

        _ = seedPerson(name: "A1", cadenceId: cadenceA, lastTouchAt: daysAgo(30))
        _ = seedPerson(name: "B1", cadenceId: cadenceB, lastTouchAt: daysAgo(30))

        let filtered = WidgetDataProvider.snapshot(context: context, groupFilter: cadenceA)
        XCTAssertTrue(filtered.hasTrackedPeople, "hasTrackedPeople must reflect unfiltered count so empty-filter and empty-app are distinguishable")
        XCTAssertEqual(filtered.featured.count, 1)
        XCTAssertEqual(filtered.featured.first?.displayName, "A1")
        XCTAssertEqual(filtered.overdueCount, 1)
    }

    func testSnapshot_excludesPausedAndDemoAndUntracked() {
        let cadenceId = UUID()
        _ = seedGroup(id: cadenceId, frequencyDays: 10, warningDays: 2)

        _ = seedPerson(name: "Active", cadenceId: cadenceId, lastTouchAt: daysAgo(30))
        _ = seedPerson(name: "Paused", cadenceId: cadenceId, lastTouchAt: daysAgo(30), isPaused: true)
        _ = seedPerson(name: "Demo", cadenceId: cadenceId, lastTouchAt: daysAgo(30), isDemoData: true)
        _ = seedPerson(name: "Untracked", cadenceId: cadenceId, lastTouchAt: daysAgo(30), isTracked: false)

        let snap = WidgetDataProvider.snapshot(context: context)
        XCTAssertEqual(snap.overdueCount, 1)
        XCTAssertEqual(snap.featured.map(\.displayName), ["Active"])
    }

    // MARK: - Parity with FrequencyCalculator (regression for #284)

    func testSnapshot_parity_customDueDateOverdue() {
        // Person would be on-track by cadence alone, but customDueDate
        // is 3 days in the past. App treats as overdue; widget must
        // now match.
        let cadenceId = UUID()
        _ = seedGroup(id: cadenceId, frequencyDays: 30, warningDays: 3)
        _ = seedPerson(
            name: "Custom",
            cadenceId: cadenceId,
            lastTouchAt: daysAgo(1),
            customDueDate: daysAgo(3)
        )

        let snap = WidgetDataProvider.snapshot(context: context)
        XCTAssertEqual(snap.overdueCount, 1, "customDueDate in the past must mark the person overdue")
        XCTAssertEqual(snap.featured.count, 1)
        if case .overdue(let days) = snap.featured.first?.status {
            XCTAssertGreaterThanOrEqual(days, 3)
        } else {
            XCTFail("Expected overdue status from customDueDate")
        }
    }

    func testSnapshot_parity_gracePeriodSeededOverdue() {
        // No lastTouchAt, but groupAddedAt is older than the cadence —
        // app's FrequencyCalculator uses groupAddedAt as the grace-period
        // anchor. Widget must agree.
        let cadenceId = UUID()
        _ = seedGroup(id: cadenceId, frequencyDays: 7, warningDays: 2)
        _ = seedPerson(
            name: "GraceSeeded",
            cadenceId: cadenceId,
            lastTouchAt: nil,
            groupAddedAt: daysAgo(30)
        )

        let snap = WidgetDataProvider.snapshot(context: context)
        XCTAssertEqual(snap.overdueCount, 1, "groupAddedAt older than cadence must count as overdue via grace-period seeding")
    }

    func testSnapshot_parity_snoozedHidesFromOverdue() {
        // Person is overdue by cadence but snoozed for 5 days → on-track.
        let cadenceId = UUID()
        _ = seedGroup(id: cadenceId, frequencyDays: 10, warningDays: 2)
        _ = seedPerson(
            name: "Snoozed",
            cadenceId: cadenceId,
            lastTouchAt: daysAgo(20),
            snoozedUntil: daysFromNow(5)
        )

        let snap = WidgetDataProvider.snapshot(context: context)
        XCTAssertEqual(snap.overdueCount, 0)
        XCTAssertTrue(snap.featured.isEmpty)
    }

    // MARK: - trackedCount (used by accessory circular gauge fill)

    func testSnapshot_trackedCount_zeroWhenEmpty() {
        let snap = WidgetDataProvider.snapshot(context: context)
        XCTAssertEqual(snap.trackedCount, 0)
    }

    func testSnapshot_trackedCount_excludesPausedAndDemoAndUntracked() {
        let cadenceId = UUID()
        _ = seedGroup(id: cadenceId, frequencyDays: 10, warningDays: 2)

        // 4 active tracked, 1 paused, 1 demo, 1 untracked → trackedCount = 4
        for i in 0..<4 {
            _ = seedPerson(name: "Active\(i)", cadenceId: cadenceId, lastTouchAt: daysAgo(2))
        }
        _ = seedPerson(name: "Paused", cadenceId: cadenceId, lastTouchAt: daysAgo(2), isPaused: true)
        _ = seedPerson(name: "Demo", cadenceId: cadenceId, lastTouchAt: daysAgo(2), isDemoData: true)
        _ = seedPerson(name: "Untracked", cadenceId: cadenceId, lastTouchAt: daysAgo(2), isTracked: false)

        let snap = WidgetDataProvider.snapshot(context: context)
        XCTAssertEqual(snap.trackedCount, 4)
    }

    func testSnapshot_trackedCount_respectsGroupFilter() {
        let cadenceA = UUID()
        let cadenceB = UUID()
        _ = seedGroup(id: cadenceA, frequencyDays: 10, warningDays: 2)
        _ = seedGroup(id: cadenceB, frequencyDays: 10, warningDays: 2)

        for i in 0..<3 { _ = seedPerson(name: "A\(i)", cadenceId: cadenceA, lastTouchAt: daysAgo(2)) }
        for i in 0..<5 { _ = seedPerson(name: "B\(i)", cadenceId: cadenceB, lastTouchAt: daysAgo(2)) }

        let unfiltered = WidgetDataProvider.snapshot(context: context)
        XCTAssertEqual(unfiltered.trackedCount, 8)

        let filteredA = WidgetDataProvider.snapshot(context: context, groupFilter: cadenceA)
        XCTAssertEqual(filteredA.trackedCount, 3)
    }

    // MARK: - Nickname

    func testSnapshot_populatesNickname_whenPersonHasNickname() {
        let cadenceId = UUID()
        _ = seedGroup(id: cadenceId, frequencyDays: 10, warningDays: 2)
        _ = seedPerson(
            name: "Robert Smith",
            cadenceId: cadenceId,
            lastTouchAt: daysAgo(30),
            nickname: "Bobby"
        )

        let snap = WidgetDataProvider.snapshot(context: context)
        XCTAssertEqual(snap.featured.first?.nickname, "Bobby")
    }

    func testSnapshot_nicknameIsNil_whenPersonHasNoNickname() {
        let cadenceId = UUID()
        _ = seedGroup(id: cadenceId, frequencyDays: 10, warningDays: 2)
        _ = seedPerson(
            name: "Alice",
            cadenceId: cadenceId,
            lastTouchAt: daysAgo(30),
            nickname: nil
        )

        let snap = WidgetDataProvider.snapshot(context: context)
        XCTAssertNil(snap.featured.first?.nickname)
    }

    // MARK: - upcomingBirthdays (#329)

    private var gregorian: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        return cal
    }

    private func refDate() -> Date {
        gregorian.date(from: DateComponents(year: 2026, month: 6, day: 15))!
    }

    private func upcoming(within days: Int = 7, limit: Int = 3, cache: [UUID: Birthday] = [:]) -> [BirthdaySummary] {
        WidgetDataProvider.upcomingBirthdays(
            context: context,
            now: refDate(),
            within: days,
            limit: limit,
            calendar: gregorian,
            cache: cache
        )
    }

    func testUpcomingBirthdays_storedOnly_filtersWindowAndSorts() {
        let cadenceId = UUID()
        _ = seedGroup(id: cadenceId, frequencyDays: 30, warningDays: 3)
        _ = seedPerson(name: "Today", cadenceId: cadenceId, birthday: Birthday(month: 6, day: 15, year: 1990))
        _ = seedPerson(name: "InThree", cadenceId: cadenceId, birthday: Birthday(month: 6, day: 18, year: nil))
        _ = seedPerson(name: "OutOfWindow", cadenceId: cadenceId, birthday: Birthday(month: 7, day: 1, year: nil))

        let result = upcoming()
        XCTAssertEqual(result.map(\.displayName), ["Today", "InThree"])
        XCTAssertEqual(result.first?.daysUntil, 0)
        XCTAssertEqual(result.last?.daysUntil, 3)
    }

    func testUpcomingBirthdays_cacheSourced_whenNoStoredBirthday() {
        let cadenceId = UUID()
        _ = seedGroup(id: cadenceId, frequencyDays: 30, warningDays: 3)
        let person = seedPerson(name: "ContactOnly", cadenceId: cadenceId, birthday: nil)

        let cache = [person.id!: Birthday(month: 6, day: 17, year: nil)]
        let result = upcoming(cache: cache)

        XCTAssertEqual(result.map(\.displayName), ["ContactOnly"])
        XCTAssertEqual(result.first?.daysUntil, 2)
    }

    func testUpcomingBirthdays_storedTakesPrecedenceOverCache() {
        let cadenceId = UUID()
        _ = seedGroup(id: cadenceId, frequencyDays: 30, warningDays: 3)
        let person = seedPerson(name: "Both", cadenceId: cadenceId, birthday: Birthday(month: 6, day: 16, year: nil))

        // Cache says day 20, but the stored birthday (day 16) must win.
        let cache = [person.id!: Birthday(month: 6, day: 20, year: nil)]
        let result = upcoming(cache: cache)

        XCTAssertEqual(result.first?.daysUntil, 1)
    }

    func testUpcomingBirthdays_excludesBirthdayNotificationsDisabled() {
        let cadenceId = UUID()
        _ = seedGroup(id: cadenceId, frequencyDays: 30, warningDays: 3)
        _ = seedPerson(name: "OptedOut", cadenceId: cadenceId, birthday: Birthday(month: 6, day: 16, year: nil), birthdayNotificationsEnabled: false)

        XCTAssertTrue(upcoming().isEmpty)
    }

    func testUpcomingBirthdays_excludesDemoData() {
        let cadenceId = UUID()
        _ = seedGroup(id: cadenceId, frequencyDays: 30, warningDays: 3)
        _ = seedPerson(name: "Demo", cadenceId: cadenceId, isDemoData: true, birthday: Birthday(month: 6, day: 16, year: nil))

        XCTAssertTrue(upcoming().isEmpty)
    }

    func testUpcomingBirthdays_includesPausedAndSnoozed() {
        let cadenceId = UUID()
        _ = seedGroup(id: cadenceId, frequencyDays: 30, warningDays: 3)
        _ = seedPerson(name: "Paused", cadenceId: cadenceId, isPaused: true, birthday: Birthday(month: 6, day: 16, year: nil))
        _ = seedPerson(name: "Snoozed", cadenceId: cadenceId, snoozedUntil: daysFromNow(30), birthday: Birthday(month: 6, day: 17, year: nil))

        XCTAssertEqual(Set(upcoming().map(\.displayName)), ["Paused", "Snoozed"])
    }

    func testUpcomingBirthdays_windowBoundary_inclusive() {
        let cadenceId = UUID()
        _ = seedGroup(id: cadenceId, frequencyDays: 30, warningDays: 3)
        _ = seedPerson(name: "Day7", cadenceId: cadenceId, birthday: Birthday(month: 6, day: 22, year: nil))   // exactly 7
        _ = seedPerson(name: "Day8", cadenceId: cadenceId, birthday: Birthday(month: 6, day: 23, year: nil))   // 8 → excluded

        XCTAssertEqual(upcoming().map(\.displayName), ["Day7"])
    }

    func testUpcomingBirthdays_respectsLimit() {
        let cadenceId = UUID()
        _ = seedGroup(id: cadenceId, frequencyDays: 30, warningDays: 3)
        for offset in 1...5 {
            _ = seedPerson(name: "P\(offset)", cadenceId: cadenceId, birthday: Birthday(month: 6, day: 15 + offset, year: nil))
        }

        XCTAssertEqual(upcoming(limit: 2).count, 2)
        XCTAssertEqual(upcoming(limit: 0).count, 5)  // 0 == no cap
    }

    func testUpcomingBirthdays_respectsGroupFilter() {
        let cadenceA = UUID()
        let cadenceB = UUID()
        _ = seedGroup(id: cadenceA, frequencyDays: 30, warningDays: 3)
        _ = seedGroup(id: cadenceB, frequencyDays: 30, warningDays: 3)
        _ = seedPerson(name: "InGroupA", cadenceId: cadenceA, birthday: Birthday(month: 6, day: 17, year: nil))
        _ = seedPerson(name: "InGroupB", cadenceId: cadenceB, birthday: Birthday(month: 6, day: 18, year: nil))

        let scopedToA = WidgetDataProvider.upcomingBirthdays(
            context: context,
            now: refDate(),
            within: 7,
            limit: 3,
            groupFilter: cadenceA,
            calendar: gregorian,
            cache: [:]
        )

        XCTAssertEqual(scopedToA.map(\.displayName), ["InGroupA"])
    }

    func testSnapshot_birthdaysFillWidget_reflectsShowBirthdaysParameter() {
        // Driven by the widget-configuration toggle (showBirthdays), not app settings.
        XCTAssertTrue(WidgetDataProvider.snapshot(context: context).birthdaysFillWidget)
        XCTAssertTrue(WidgetDataProvider.snapshot(context: context, showBirthdays: true).birthdaysFillWidget)
        XCTAssertFalse(WidgetDataProvider.snapshot(context: context, showBirthdays: false).birthdaysFillWidget)
    }

    // MARK: - nextLocalMidnight (#329)

    func testNextLocalMidnight_isStartOfTomorrow() {
        let ref = gregorian.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 14, minute: 30))!
        let midnight = WidgetDataProvider.nextLocalMidnight(after: ref, calendar: gregorian)
        let comps = gregorian.dateComponents([.year, .month, .day, .hour, .minute], from: midnight)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 6)
        XCTAssertEqual(comps.day, 16)
        XCTAssertEqual(comps.hour, 0)
        XCTAssertEqual(comps.minute, 0)
    }

    func testNextLocalMidnight_isStrictlyAfterEvenAtMidnight() {
        let midnightExact = gregorian.startOfDay(for: gregorian.date(from: DateComponents(year: 2026, month: 6, day: 15))!)
        let next = WidgetDataProvider.nextLocalMidnight(after: midnightExact, calendar: gregorian)
        XCTAssertEqual(gregorian.dateComponents([.day], from: next).day, 16)
    }

    // MARK: - soonestBirthdayCohort (#329)

    private func summary(_ name: String, daysUntil: Int) -> BirthdaySummary {
        BirthdaySummary(
            id: UUID(),
            displayName: name,
            nickname: nil,
            initials: String(name.prefix(2)),
            avatarColorHex: "#FF6B6B",
            daysUntil: daysUntil,
            nextOccurrence: Date()
        )
    }

    func testCohort_nilWhenEmpty() {
        XCTAssertNil(WidgetDataProvider.soonestBirthdayCohort(from: []))
    }

    func testCohort_singlePerson() {
        let cohort = WidgetDataProvider.soonestBirthdayCohort(from: [summary("Mom", daysUntil: 1)])
        XCTAssertEqual(cohort?.additionalCount, 0)
        XCTAssertEqual(cohort?.stackedAvatars.count, 1)
        XCTAssertEqual(cohort?.smallWidgetName, "Mom")
    }

    func testCohort_groupsOnlySameDayAsSoonest() {
        // Sorted ascending, as upcomingBirthdays returns it.
        let cohort = WidgetDataProvider.soonestBirthdayCohort(from: [
            summary("Mom", daysUntil: 1),
            summary("Kate", daysUntil: 1),
            summary("John", daysUntil: 5),
        ])
        XCTAssertEqual(cohort?.primary.displayName, "Mom")
        XCTAssertEqual(cohort?.sameDay.count, 2, "Only Mom + Kate share day 1; John is day 5")
        XCTAssertEqual(cohort?.additionalCount, 1)
        XCTAssertEqual(cohort?.smallWidgetName, "Mom +1")
    }

    func testCohort_avatarsCapAtThreeButCountIsFull() {
        let cohort = WidgetDataProvider.soonestBirthdayCohort(from: [
            summary("A", daysUntil: 0),
            summary("B", daysUntil: 0),
            summary("C", daysUntil: 0),
            summary("D", daysUntil: 0),
            summary("E", daysUntil: 0),
        ])
        XCTAssertEqual(cohort?.stackedAvatars.count, 3, "Avatars cap at 3")
        XCTAssertEqual(cohort?.additionalCount, 4, "But +N reflects the true extra count")
        XCTAssertEqual(cohort?.smallWidgetName, "A +4")
    }

    func testCohortsByDay_groupsConsecutiveSameDay() {
        let cohorts = WidgetDataProvider.birthdayCohortsByDay(from: [
            summary("Daniel", daysUntil: 1),
            summary("Hank", daysUntil: 1),
            summary("Kate", daysUntil: 1),
            summary("John", daysUntil: 5),
        ])
        XCTAssertEqual(cohorts.count, 2, "Two distinct days → two cohorts")
        XCTAssertEqual(cohorts[0].primary.displayName, "Daniel")
        XCTAssertEqual(cohorts[0].additionalCount, 2, "Hank + Kate share Daniel's day")
        XCTAssertEqual(cohorts[0].smallWidgetName, "Daniel +2")
        XCTAssertEqual(cohorts[1].primary.displayName, "John")
        XCTAssertEqual(cohorts[1].additionalCount, 0)
    }

    func testCohort_birthdayHeadline() {
        func headline(_ days: Int, count: Int) -> String {
            let list = (0..<count).map { summary("P\($0)", daysUntil: days) }
            return WidgetDataProvider.soonestBirthdayCohort(from: list)!.birthdayHeadline
        }
        XCTAssertEqual(headline(0, count: 1), "Birthday today")
        XCTAssertEqual(headline(1, count: 1), "Birthday tomorrow")
        XCTAssertEqual(headline(5, count: 1), "Birthday upcoming")
        XCTAssertEqual(headline(1, count: 2), "Birthdays tomorrow")
        XCTAssertEqual(headline(0, count: 3), "Birthdays today")
        XCTAssertEqual(headline(6, count: 2), "Birthdays upcoming")
    }

    func testCohortsByDay_emptyInput() {
        XCTAssertTrue(WidgetDataProvider.birthdayCohortsByDay(from: []).isEmpty)
    }

    func testCohortsByDay_allDistinctDays() {
        let cohorts = WidgetDataProvider.birthdayCohortsByDay(from: [
            summary("A", daysUntil: 0),
            summary("B", daysUntil: 2),
            summary("C", daysUntil: 4),
        ])
        XCTAssertEqual(cohorts.count, 3)
        XCTAssertTrue(cohorts.allSatisfy { $0.additionalCount == 0 })
    }

    func testCohort_tapURL_personWhenAloneOverviewWhenShared() {
        let alone = WidgetDataProvider.soonestBirthdayCohort(from: [summary("Mom", daysUntil: 1)])!
        XCTAssertEqual(alone.tapURL, DeepLinkRoute.person(alone.primary.id).url())

        let shared = WidgetDataProvider.soonestBirthdayCohort(from: [
            summary("Mom", daysUntil: 1), summary("Kate", daysUntil: 1),
        ])!
        XCTAssertEqual(shared.tapURL, DeepLinkRoute.overdue.url())
    }

    // MARK: - Fixtures

    private func makeOverduePerson(name: String, status: WidgetPersonStatus, nickname: String? = nil) -> OverduePerson {
        OverduePerson(
            id: UUID(),
            displayName: name,
            nickname: nickname,
            initials: String(name.prefix(2)),
            avatarColorHex: "#FF6B6B",
            groupName: "Friends",
            groupColorHex: nil,
            status: status
        )
    }

    @discardableResult
    private func seedGroup(
        id: UUID,
        name: String = "Friends",
        frequencyDays: Int,
        warningDays: Int
    ) -> GroupEntity {
        let entity = GroupEntity(context: context)
        entity.id = id
        entity.name = name
        entity.frequencyDays = Int64(frequencyDays)
        entity.warningDays = Int64(warningDays)
        entity.isDefault = false
        entity.sortOrder = 0
        entity.createdAt = Date()
        entity.modifiedAt = Date()
        try? context.save()
        return entity
    }

    @discardableResult
    private func seedPerson(
        name: String,
        cadenceId: UUID,
        lastTouchAt: Date? = nil,
        customDueDate: Date? = nil,
        snoozedUntil: Date? = nil,
        groupAddedAt: Date? = nil,
        isPaused: Bool = false,
        isTracked: Bool = true,
        isDemoData: Bool = false,
        nickname: String? = nil,
        birthday: Birthday? = nil,
        birthdayNotificationsEnabled: Bool = true
    ) -> PersonEntity {
        let entity = PersonEntity(context: context)
        entity.id = UUID()
        entity.displayName = name
        entity.initials = String(name.prefix(2))
        entity.avatarColor = "#FF6B6B"
        entity.groupId = cadenceId
        entity.lastTouchAt = lastTouchAt
        entity.customDueDate = customDueDate
        entity.snoozedUntil = snoozedUntil
        entity.groupAddedAt = groupAddedAt
        entity.isPaused = isPaused
        entity.isTracked = isTracked
        entity.isDemoData = isDemoData
        entity.notificationsMuted = false
        entity.contactUnavailable = false
        entity.birthdayNotificationsEnabled = birthdayNotificationsEnabled
        entity.birthday = birthday?.toJsonString()
        entity.nickname = nickname
        entity.sortOrder = 0
        entity.createdAt = Date()
        entity.modifiedAt = Date()
        try? context.save()
        return entity
    }

    private func daysAgo(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: Date())!
    }

    private func daysFromNow(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: n, to: Date())!
    }
}
