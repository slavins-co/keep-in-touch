//
//  AccessoryWidgetLogicTests.swift
//  StayInTouchTests
//
//  Pure-logic coverage for the Lock Screen / StandBy accessory widgets.
//  Issue #279.
//

import XCTest
@testable import StayInTouch

final class AccessoryWidgetLogicTests: XCTestCase {

    // MARK: - ring(...)

    func testRing_emptyWhenNoTrackedPeople() {
        XCTAssertEqual(
            AccessoryWidgetLogic.ring(overdueCount: 0, dueSoonCount: 0, trackedCount: 0, hasTrackedPeople: false),
            .empty
        )
    }

    func testRing_emptyWhenAllCaughtUp() {
        XCTAssertEqual(
            AccessoryWidgetLogic.ring(overdueCount: 0, dueSoonCount: 0, trackedCount: 5, hasTrackedPeople: true),
            .empty
        )
    }

    func testRing_gaugeOverdueOnly() {
        // 3 overdue out of 10 tracked → overdue fraction = 0.3
        let result = AccessoryWidgetLogic.ring(overdueCount: 3, dueSoonCount: 0, trackedCount: 10, hasTrackedPeople: true)
        if case .gauge(let overdueFraction, let dueSoonFraction) = result {
            XCTAssertEqual(overdueFraction, 0.3, accuracy: 0.0001)
            XCTAssertEqual(dueSoonFraction, 0.0, accuracy: 0.0001)
        } else {
            XCTFail("Expected .gauge, got \(result)")
        }
    }

    func testRing_gaugeDueSoonOnly() {
        // 0 overdue + 3 dueSoon out of 10 tracked → dueSoon fraction = 0.3
        let result = AccessoryWidgetLogic.ring(overdueCount: 0, dueSoonCount: 3, trackedCount: 10, hasTrackedPeople: true)
        if case .gauge(let overdueFraction, let dueSoonFraction) = result {
            XCTAssertEqual(overdueFraction, 0.0, accuracy: 0.0001)
            XCTAssertEqual(dueSoonFraction, 0.3, accuracy: 0.0001)
        } else {
            XCTFail("Expected .gauge, got \(result)")
        }
    }

    func testRing_gaugeBothCategoriesProportionalToTracked() {
        // 3 overdue + 2 dueSoon out of 10 tracked → 0.3 + 0.2, remainder 0.5
        let result = AccessoryWidgetLogic.ring(overdueCount: 3, dueSoonCount: 2, trackedCount: 10, hasTrackedPeople: true)
        if case .gauge(let overdueFraction, let dueSoonFraction) = result {
            XCTAssertEqual(overdueFraction, 0.3, accuracy: 0.0001)
            XCTAssertEqual(dueSoonFraction, 0.2, accuracy: 0.0001)
        } else {
            XCTFail("Expected .gauge, got \(result)")
        }
    }

    func testRing_gaugeFullWhenEveryoneAtRisk() {
        // 3 overdue + 2 dueSoon out of 5 tracked → fractions sum to 1.0
        let result = AccessoryWidgetLogic.ring(overdueCount: 3, dueSoonCount: 2, trackedCount: 5, hasTrackedPeople: true)
        if case .gauge(let overdueFraction, let dueSoonFraction) = result {
            XCTAssertEqual(overdueFraction, 0.6, accuracy: 0.0001)
            XCTAssertEqual(dueSoonFraction, 0.4, accuracy: 0.0001)
        } else {
            XCTFail("Expected .gauge, got \(result)")
        }
    }

    func testRing_gaugeDefensiveWhenTrackedCountUnderAtRisk() {
        // Defensive: if data is inconsistent (atRisk > tracked), fall back
        // to filling the ring proportional to atRisk so we never divide
        // by zero or compute >100% fill.
        let result = AccessoryWidgetLogic.ring(overdueCount: 3, dueSoonCount: 2, trackedCount: 0, hasTrackedPeople: true)
        if case .gauge(let overdueFraction, let dueSoonFraction) = result {
            XCTAssertEqual(overdueFraction, 0.6, accuracy: 0.0001, "Falls back to atRisk-relative fill when trackedCount is degenerate")
            XCTAssertEqual(dueSoonFraction, 0.4, accuracy: 0.0001)
        } else {
            XCTFail("Expected .gauge, got \(result)")
        }
    }

    // MARK: - centerDigit(...)

    func testCenterDigit_showsTotalAtRiskWhenBothBucketsPresent() {
        XCTAssertEqual(
            AccessoryWidgetLogic.centerDigit(overdueCount: 3, dueSoonCount: 2, hasTrackedPeople: true),
            "5",
            "Lock-screen rendering loses two-tone color, so we show total at-risk count"
        )
    }

    func testCenterDigit_showsOverdueOnly() {
        XCTAssertEqual(
            AccessoryWidgetLogic.centerDigit(overdueCount: 3, dueSoonCount: 0, hasTrackedPeople: true),
            "3"
        )
    }

    func testCenterDigit_showsDueSoonOnly() {
        XCTAssertEqual(
            AccessoryWidgetLogic.centerDigit(overdueCount: 0, dueSoonCount: 4, hasTrackedPeople: true),
            "4"
        )
    }

    func testCenterDigit_nilWhenAllCaughtUp() {
        XCTAssertNil(
            AccessoryWidgetLogic.centerDigit(overdueCount: 0, dueSoonCount: 0, hasTrackedPeople: true)
        )
    }

    func testCenterDigit_nilWhenNoTrackedPeople() {
        XCTAssertNil(
            AccessoryWidgetLogic.centerDigit(overdueCount: 0, dueSoonCount: 0, hasTrackedPeople: false)
        )
    }

    // MARK: - rectangularSubtitle(...)

    func testRectangularSubtitle_overdueDaysWithMore() {
        XCTAssertEqual(
            AccessoryWidgetLogic.rectangularSubtitle(
                featuredStatus: .overdue(daysOverdue: 3),
                additionalAtRisk: 2
            ),
            "3d overdue · 2 more"
        )
    }

    func testRectangularSubtitle_overdueDaysAlone() {
        XCTAssertEqual(
            AccessoryWidgetLogic.rectangularSubtitle(
                featuredStatus: .overdue(daysOverdue: 1),
                additionalAtRisk: 0
            ),
            "1d overdue"
        )
    }

    func testRectangularSubtitle_dueTodayWithMore() {
        XCTAssertEqual(
            AccessoryWidgetLogic.rectangularSubtitle(
                featuredStatus: .dueSoon(daysUntilDue: 0),
                additionalAtRisk: 2
            ),
            "Due today · 2 more"
        )
    }

    func testRectangularSubtitle_dueTodayAlone() {
        XCTAssertEqual(
            AccessoryWidgetLogic.rectangularSubtitle(
                featuredStatus: .dueSoon(daysUntilDue: 0),
                additionalAtRisk: 0
            ),
            "Due today"
        )
    }

    func testRectangularSubtitle_dueSoonDays() {
        XCTAssertEqual(
            AccessoryWidgetLogic.rectangularSubtitle(
                featuredStatus: .dueSoon(daysUntilDue: 2),
                additionalAtRisk: 0
            ),
            "Due in 2d"
        )
    }

    func testRectangularSubtitle_dueSoonDaysWithMore() {
        XCTAssertEqual(
            AccessoryWidgetLogic.rectangularSubtitle(
                featuredStatus: .dueSoon(daysUntilDue: 3),
                additionalAtRisk: 1
            ),
            "Due in 3d · 1 more"
        )
    }

    // MARK: - inlineLabel(...)

    func testInlineLabel_overdueWithFeatured() {
        let snapshot = makeSnapshot(
            overdueCount: 3,
            dueSoonCount: 0,
            featured: [makeFeatured(displayName: "Mom", nickname: nil, status: .overdue(daysOverdue: 5))]
        )
        let label = AccessoryWidgetLogic.inlineLabel(snapshot: snapshot)
        XCTAssertEqual(label.symbol, "person.crop.circle.fill")
        XCTAssertEqual(label.text, "3 overdue · Mom next")
    }

    func testInlineLabel_dueSoonWithFeatured_whenNoOverdue() {
        let snapshot = makeSnapshot(
            overdueCount: 0,
            dueSoonCount: 2,
            featured: [makeFeatured(displayName: "Sam", nickname: nil, status: .dueSoon(daysUntilDue: 1))]
        )
        let label = AccessoryWidgetLogic.inlineLabel(snapshot: snapshot)
        XCTAssertEqual(label.symbol, "person.crop.circle.fill")
        XCTAssertEqual(label.text, "2 due soon · Sam next")
    }

    func testInlineLabel_prefersNicknameOverFirstName() {
        let snapshot = makeSnapshot(
            overdueCount: 1,
            dueSoonCount: 0,
            featured: [makeFeatured(displayName: "Robert Smith", nickname: "Bobby", status: .overdue(daysOverdue: 2))]
        )
        XCTAssertEqual(AccessoryWidgetLogic.inlineLabel(snapshot: snapshot).text, "1 overdue · Bobby next")
    }

    func testInlineLabel_fallsBackToFirstNameWhenNoNickname() {
        let snapshot = makeSnapshot(
            overdueCount: 1,
            dueSoonCount: 0,
            featured: [makeFeatured(displayName: "Robert Smith", nickname: nil, status: .overdue(daysOverdue: 2))]
        )
        XCTAssertEqual(AccessoryWidgetLogic.inlineLabel(snapshot: snapshot).text, "1 overdue · Robert next")
    }

    func testInlineLabel_allCaughtUp() {
        let snapshot = makeSnapshot(overdueCount: 0, dueSoonCount: 0, featured: [], hasTrackedPeople: true)
        let label = AccessoryWidgetLogic.inlineLabel(snapshot: snapshot)
        XCTAssertEqual(label.symbol, "hand.wave.fill")
        XCTAssertEqual(label.text, "All caught up")
    }

    func testInlineLabel_noTrackedPeople() {
        let snapshot = makeSnapshot(overdueCount: 0, dueSoonCount: 0, featured: [], hasTrackedPeople: false)
        let label = AccessoryWidgetLogic.inlineLabel(snapshot: snapshot)
        XCTAssertEqual(label.symbol, "person.crop.circle.badge.plus")
        XCTAssertEqual(label.text, "Add someone to track")
    }

    // MARK: - displayShortName logic via OverduePerson

    func testDisplayShortName_prefersNickname() {
        let person = makeFeatured(displayName: "Robert Smith", nickname: "Bobby", status: .overdue(daysOverdue: 1))
        XCTAssertEqual(person.displayShortName, "Bobby")
    }

    func testDisplayShortName_trimsNicknameWhitespace() {
        let person = makeFeatured(displayName: "Robert", nickname: "  Bobby  ", status: .overdue(daysOverdue: 1))
        XCTAssertEqual(person.displayShortName, "Bobby")
    }

    func testDisplayShortName_fallsBackToFirstNameForBlankNickname() {
        let person = makeFeatured(displayName: "Robert Smith", nickname: "   ", status: .overdue(daysOverdue: 1))
        XCTAssertEqual(person.displayShortName, "Robert")
    }

    func testDisplayShortName_fallsBackToFirstNameWhenNicknameNil() {
        let person = makeFeatured(displayName: "Robert Smith", nickname: nil, status: .overdue(daysOverdue: 1))
        XCTAssertEqual(person.displayShortName, "Robert")
    }

    func testDisplayShortName_singleWordDisplayName() {
        let person = makeFeatured(displayName: "Robert", nickname: nil, status: .overdue(daysOverdue: 1))
        XCTAssertEqual(person.displayShortName, "Robert")
    }

    func testDisplayShortName_emptyDisplayNameDoesNotCrash() {
        let person = makeFeatured(displayName: "", nickname: nil, status: .overdue(daysOverdue: 1))
        XCTAssertEqual(person.displayShortName, "")
    }

    // MARK: - Fixtures

    private func makeFeatured(displayName: String, nickname: String?, status: WidgetPersonStatus) -> OverduePerson {
        OverduePerson(
            id: UUID(),
            displayName: displayName,
            nickname: nickname,
            initials: String(displayName.prefix(2)),
            avatarColorHex: "#FF6B6B",
            groupName: "Friends",
            groupColorHex: nil,
            status: status
        )
    }

    // MARK: - Rectangular birthday precedence (#329)

    func testRectangularBirthday_nil_whenNoBirthdays() {
        let snap = makeSnapshot(overdueCount: 3, dueSoonCount: 0, featured: [])
        XCTAssertNil(AccessoryWidgetLogic.rectangularBirthday(snapshot: snap))
    }

    func testRectangularBirthday_nil_whenBeyondThreshold() {
        let snap = makeSnapshot(
            overdueCount: 1, dueSoonCount: 0, featured: [],
            upcomingBirthdays: [makeBirthday(name: "Mom", daysUntil: 3)]
        )
        XCTAssertNil(AccessoryWidgetLogic.rectangularBirthday(snapshot: snap), "3 days out is beyond the 2-day threshold")
    }

    func testRectangularBirthday_returnedWithinThreshold() {
        for days in 0...2 {
            let snap = makeSnapshot(
                overdueCount: 4, dueSoonCount: 0, featured: [],
                upcomingBirthdays: [makeBirthday(name: "Mom", daysUntil: days)]
            )
            let result = AccessoryWidgetLogic.rectangularBirthday(snapshot: snap)
            XCTAssertEqual(result?.name, "Mom")
            XCTAssertEqual(result?.daysUntil, days)
            XCTAssertEqual(result?.overdueCount, 4)
        }
    }

    func testRectangularBirthdaySubtitle_composition() {
        let today = AccessoryWidgetLogic.RectangularBirthday(id: UUID(), name: "Mom", daysUntil: 0, overdueCount: 0, sameDayAdditional: 0)
        XCTAssertEqual(AccessoryWidgetLogic.rectangularBirthdaySubtitle(today), "today")

        let tomorrowWithOverdue = AccessoryWidgetLogic.RectangularBirthday(id: UUID(), name: "Mom", daysUntil: 1, overdueCount: 3, sameDayAdditional: 0)
        XCTAssertEqual(AccessoryWidgetLogic.rectangularBirthdaySubtitle(tomorrowWithOverdue), "tomorrow · 3 overdue")

        let inTwo = AccessoryWidgetLogic.RectangularBirthday(id: UUID(), name: "Mom", daysUntil: 2, overdueCount: 0, sameDayAdditional: 0)
        XCTAssertEqual(AccessoryWidgetLogic.rectangularBirthdaySubtitle(inTwo), "in 2 days")
    }

    func testRectangularBirthday_displayName_appendsPlusNForSameDay() {
        let alone = AccessoryWidgetLogic.RectangularBirthday(id: UUID(), name: "Mom", daysUntil: 0, overdueCount: 0, sameDayAdditional: 0)
        XCTAssertEqual(alone.displayName, "Mom")

        let shared = AccessoryWidgetLogic.RectangularBirthday(id: UUID(), name: "Mom", daysUntil: 0, overdueCount: 0, sameDayAdditional: 2)
        XCTAssertEqual(shared.displayName, "Mom +2")
    }

    func testRectangularBirthday_countsSameDayCohort() {
        let snap = makeSnapshot(
            overdueCount: 0, dueSoonCount: 0, featured: [],
            upcomingBirthdays: [
                makeBirthday(name: "Mom", daysUntil: 1),
                makeBirthday(name: "Kate", daysUntil: 1),
                makeBirthday(name: "John", daysUntil: 5),  // different day — excluded from cohort
            ]
        )
        let result = AccessoryWidgetLogic.rectangularBirthday(snapshot: snap)
        XCTAssertEqual(result?.name, "Mom")
        XCTAssertEqual(result?.sameDayAdditional, 1, "Kate shares the day; John does not")
        XCTAssertEqual(result?.displayName, "Mom +1")
    }

    private func makeBirthday(name: String, daysUntil: Int) -> BirthdaySummary {
        BirthdaySummary(
            id: UUID(),
            displayName: name,
            nickname: nil,
            initials: String(name.prefix(2)),
            avatarColorHex: "#A78BFA",
            daysUntil: daysUntil,
            nextOccurrence: Date()
        )
    }

    private func makeSnapshot(
        overdueCount: Int,
        dueSoonCount: Int,
        featured: [OverduePerson],
        hasTrackedPeople: Bool = true,
        trackedCount: Int = 5,
        upcomingBirthdays: [BirthdaySummary] = [],
        birthdaysFillWidget: Bool = true
    ) -> WidgetDataProvider.Snapshot {
        WidgetDataProvider.Snapshot(
            overdueCount: overdueCount,
            dueSoonCount: dueSoonCount,
            featured: featured,
            hasTrackedPeople: hasTrackedPeople,
            trackedCount: trackedCount,
            themeOverride: nil,
            upcomingBirthdays: upcomingBirthdays,
            birthdaysFillWidget: birthdaysFillWidget
        )
    }
}
