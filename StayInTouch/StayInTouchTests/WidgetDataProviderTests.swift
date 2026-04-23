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

    // MARK: - Fixtures

    private func makeOverduePerson(name: String, status: WidgetPersonStatus) -> OverduePerson {
        OverduePerson(
            id: UUID(),
            displayName: name,
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
        isDemoData: Bool = false
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
        entity.birthdayNotificationsEnabled = true
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
