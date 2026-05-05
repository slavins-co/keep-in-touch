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
            AccessoryWidgetLogic.ring(overdueCount: 0, dueSoonCount: 0, hasTrackedPeople: false),
            .empty
        )
    }

    func testRing_emptyWhenAllCaughtUp() {
        XCTAssertEqual(
            AccessoryWidgetLogic.ring(overdueCount: 0, dueSoonCount: 0, hasTrackedPeople: true),
            .empty
        )
    }

    func testRing_binaryOverdueWhenOnlyOverdue() {
        XCTAssertEqual(
            AccessoryWidgetLogic.ring(overdueCount: 3, dueSoonCount: 0, hasTrackedPeople: true),
            .binary(color: .overdue)
        )
    }

    func testRing_binaryDueSoonWhenOnlyDueSoon() {
        XCTAssertEqual(
            AccessoryWidgetLogic.ring(overdueCount: 0, dueSoonCount: 3, hasTrackedPeople: true),
            .binary(color: .dueSoon)
        )
    }

    func testRing_twoToneFractionWhenBothCategoriesPresent() {
        // 3 overdue + 2 due-soon → overdue fraction = 0.6
        let result = AccessoryWidgetLogic.ring(overdueCount: 3, dueSoonCount: 2, hasTrackedPeople: true)
        if case .twoTone(let fraction) = result {
            XCTAssertEqual(fraction, 0.6, accuracy: 0.0001)
        } else {
            XCTFail("Expected .twoTone, got \(result)")
        }
    }

    func testRing_twoToneEvenSplit() {
        // 1 overdue + 1 due-soon → overdue fraction = 0.5
        let result = AccessoryWidgetLogic.ring(overdueCount: 1, dueSoonCount: 1, hasTrackedPeople: true)
        if case .twoTone(let fraction) = result {
            XCTAssertEqual(fraction, 0.5, accuracy: 0.0001)
        } else {
            XCTFail("Expected .twoTone, got \(result)")
        }
    }

    // MARK: - centerDigit(...)

    func testCenterDigit_showsOverdueWhenAny() {
        XCTAssertEqual(
            AccessoryWidgetLogic.centerDigit(overdueCount: 3, dueSoonCount: 2, hasTrackedPeople: true),
            "3"
        )
    }

    func testCenterDigit_showsDueSoonWhenNoOverdue() {
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
        XCTAssertEqual(label.symbol, "exclamationmark.circle.fill")
        XCTAssertEqual(label.text, "3 overdue · Mom next")
    }

    func testInlineLabel_dueSoonWithFeatured_whenNoOverdue() {
        let snapshot = makeSnapshot(
            overdueCount: 0,
            dueSoonCount: 2,
            featured: [makeFeatured(displayName: "Sam", nickname: nil, status: .dueSoon(daysUntilDue: 1))]
        )
        let label = AccessoryWidgetLogic.inlineLabel(snapshot: snapshot)
        XCTAssertEqual(label.symbol, "clock.fill")
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

    private func makeSnapshot(
        overdueCount: Int,
        dueSoonCount: Int,
        featured: [OverduePerson],
        hasTrackedPeople: Bool = true
    ) -> WidgetDataProvider.Snapshot {
        WidgetDataProvider.Snapshot(
            overdueCount: overdueCount,
            dueSoonCount: dueSoonCount,
            featured: featured,
            hasTrackedPeople: hasTrackedPeople,
            themeOverride: nil
        )
    }
}
