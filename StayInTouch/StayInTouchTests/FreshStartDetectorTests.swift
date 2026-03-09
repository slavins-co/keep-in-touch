//
//  FreshStartDetectorTests.swift
//  KeepInTouchTests
//

import XCTest
@testable import StayInTouch

final class FreshStartDetectorTests: XCTestCase {
    private let detector = FreshStartDetector()
    private let now = Date()

    private func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: now)!
    }

    // MARK: - Minimum Contact Count

    func testDoNotShowWhenBelowMinContacts() {
        let input = FreshStartDetector.Input(
            trackedCount: 4,
            overdueCount: 4,
            lastAppOpenedAt: daysAgo(30),
            lastDismissedAt: nil,
            referenceDate: now
        )
        XCTAssertEqual(detector.evaluate(input), .doNotShow)
    }

    // MARK: - Small List Tier (5-9 contacts, 80% threshold)

    func testSmallListShowsWhenAtThreshold() {
        let input = FreshStartDetector.Input(
            trackedCount: 5,
            overdueCount: 4,
            lastAppOpenedAt: nil,
            lastDismissedAt: nil,
            referenceDate: now
        )
        XCTAssertEqual(detector.evaluate(input), .showPrompt(reason: .overwhelmed))
    }

    func testSmallListDoesNotShowBelowThreshold() {
        let input = FreshStartDetector.Input(
            trackedCount: 5,
            overdueCount: 3,
            lastAppOpenedAt: nil,
            lastDismissedAt: nil,
            referenceDate: now
        )
        XCTAssertEqual(detector.evaluate(input), .doNotShow)
    }

    // MARK: - Medium List Tier (10-19 contacts, 70% threshold)

    func testMediumListShowsWhenOverThreshold() {
        let input = FreshStartDetector.Input(
            trackedCount: 15,
            overdueCount: 11,
            lastAppOpenedAt: nil,
            lastDismissedAt: nil,
            referenceDate: now
        )
        XCTAssertEqual(detector.evaluate(input), .showPrompt(reason: .overwhelmed))
    }

    func testMediumListDoesNotShowBelowThreshold() {
        let input = FreshStartDetector.Input(
            trackedCount: 15,
            overdueCount: 10,
            lastAppOpenedAt: nil,
            lastDismissedAt: nil,
            referenceDate: now
        )
        XCTAssertEqual(detector.evaluate(input), .doNotShow)
    }

    // MARK: - Large List Tier (20+ contacts, 60% threshold)

    func testLargeListShowsWhenOverThreshold() {
        let input = FreshStartDetector.Input(
            trackedCount: 25,
            overdueCount: 16,
            lastAppOpenedAt: nil,
            lastDismissedAt: nil,
            referenceDate: now
        )
        XCTAssertEqual(detector.evaluate(input), .showPrompt(reason: .overwhelmed))
    }

    func testLargeListDoesNotShowBelowThreshold() {
        let input = FreshStartDetector.Input(
            trackedCount: 25,
            overdueCount: 14,
            lastAppOpenedAt: nil,
            lastDismissedAt: nil,
            referenceDate: now
        )
        XCTAssertEqual(detector.evaluate(input), .doNotShow)
    }

    // MARK: - Inactivity

    func testShowsWhenInactive() {
        let input = FreshStartDetector.Input(
            trackedCount: 10,
            overdueCount: 0,
            lastAppOpenedAt: daysAgo(14),
            lastDismissedAt: nil,
            referenceDate: now
        )
        XCTAssertEqual(detector.evaluate(input), .showPrompt(reason: .inactive))
    }

    func testDoesNotShowWhenNotInactiveEnough() {
        let input = FreshStartDetector.Input(
            trackedCount: 10,
            overdueCount: 0,
            lastAppOpenedAt: daysAgo(13),
            lastDismissedAt: nil,
            referenceDate: now
        )
        XCTAssertEqual(detector.evaluate(input), .doNotShow)
    }

    func testNilLastAppOpenedDoesNotTriggerInactive() {
        let input = FreshStartDetector.Input(
            trackedCount: 10,
            overdueCount: 0,
            lastAppOpenedAt: nil,
            lastDismissedAt: nil,
            referenceDate: now
        )
        XCTAssertEqual(detector.evaluate(input), .doNotShow)
    }

    // MARK: - Both Conditions

    func testShowsBothWhenOverwhelmedAndInactive() {
        let input = FreshStartDetector.Input(
            trackedCount: 10,
            overdueCount: 8,
            lastAppOpenedAt: daysAgo(20),
            lastDismissedAt: nil,
            referenceDate: now
        )
        XCTAssertEqual(detector.evaluate(input), .showPrompt(reason: .both))
    }

    // MARK: - Cooldown

    func testCooldownPreventsPrompt() {
        let input = FreshStartDetector.Input(
            trackedCount: 10,
            overdueCount: 10,
            lastAppOpenedAt: daysAgo(30),
            lastDismissedAt: daysAgo(15),
            referenceDate: now
        )
        XCTAssertEqual(detector.evaluate(input), .doNotShow)
    }

    func testCooldownExpiredShowsPrompt() {
        let input = FreshStartDetector.Input(
            trackedCount: 10,
            overdueCount: 10,
            lastAppOpenedAt: nil,
            lastDismissedAt: daysAgo(31),
            referenceDate: now
        )
        XCTAssertEqual(detector.evaluate(input), .showPrompt(reason: .overwhelmed))
    }

    // MARK: - Threshold Function

    func testOverdueThresholdTiers() {
        XCTAssertEqual(FreshStartDetector.overdueThreshold(for: 5), 0.80)
        XCTAssertEqual(FreshStartDetector.overdueThreshold(for: 9), 0.80)
        XCTAssertEqual(FreshStartDetector.overdueThreshold(for: 10), 0.70)
        XCTAssertEqual(FreshStartDetector.overdueThreshold(for: 19), 0.70)
        XCTAssertEqual(FreshStartDetector.overdueThreshold(for: 20), 0.60)
        XCTAssertEqual(FreshStartDetector.overdueThreshold(for: 100), 0.60)
    }
}
