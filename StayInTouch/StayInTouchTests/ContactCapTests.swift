//
//  ContactCapTests.swift
//  KeepInTouchTests
//
//  Pure cap-gate logic (#351, PR3) + the repository tracked-count it depends on.
//

import CoreData
import XCTest
@testable import StayInTouch

final class ContactCapTests: XCTestCase {

    // MARK: - ContactCapGate.wouldExceedFreeLimit

    func testCap_proIsNeverLimited() {
        XCTAssertFalse(ContactCapGate.wouldExceedFreeLimit(currentTrackedCount: 999, adding: 50, isPro: true))
    }

    func testCap_freeUnderLimit_allowed() {
        // 6 + 3 = 9 <= 12
        XCTAssertFalse(ContactCapGate.wouldExceedFreeLimit(currentTrackedCount: 6, adding: 3, isPro: false))
    }

    func testCap_freeExactlyAtLimit_allowed() {
        // 10 + 2 = 12 (== limit) is allowed; only > 12 is blocked.
        XCTAssertFalse(ContactCapGate.wouldExceedFreeLimit(currentTrackedCount: 10, adding: 2, isPro: false))
    }

    func testCap_freeOverLimit_blocked() {
        // 10 + 3 = 13 > 12
        XCTAssertTrue(ContactCapGate.wouldExceedFreeLimit(currentTrackedCount: 10, adding: 3, isPro: false))
    }

    func testCap_freeAtLimitAddingOne_blocked() {
        XCTAssertTrue(ContactCapGate.wouldExceedFreeLimit(currentTrackedCount: 12, adding: 1, isPro: false))
    }

    func testCap_batchFromEmptyOverLimit_blocked() {
        // From an empty base (e.g. trackedCount == 0), a batch of 13 is blocked,
        // 12 is allowed. (Pure-function coverage; the onboarding *flow* gate lands
        // in a later PR.)
        XCTAssertTrue(ContactCapGate.wouldExceedFreeLimit(currentTrackedCount: 0, adding: 13, isPro: false))
        XCTAssertFalse(ContactCapGate.wouldExceedFreeLimit(currentTrackedCount: 0, adding: 12, isPro: false))
    }

    // MARK: - ContactCapGate.remainingFreeSlots

    func testRemaining_proIsNil() {
        XCTAssertNil(ContactCapGate.remainingFreeSlots(currentTrackedCount: 5, isPro: true))
    }

    func testRemaining_freeClampedToZero() {
        XCTAssertEqual(ContactCapGate.remainingFreeSlots(currentTrackedCount: 5, isPro: false), 7)
        XCTAssertEqual(ContactCapGate.remainingFreeSlots(currentTrackedCount: 12, isPro: false), 0)
        XCTAssertEqual(ContactCapGate.remainingFreeSlots(currentTrackedCount: 20, isPro: false), 0)
    }

    // MARK: - Repository trackedCount (isTracked && !isDemoData, paused included)

    func testTrackedCount_countsTrackedNonDemoIncludingPaused() throws {
        let context = CoreDataTestStack().container.viewContext
        let repo = CoreDataPersonRepository(context: context)

        try repo.save(TestFactory.makePerson(name: "Active"))
        try repo.save(TestFactory.makePerson(name: "Paused", isPaused: true))   // paused still counts
        try repo.save(TestFactory.makePerson(name: "Untracked", isTracked: false)) // excluded
        try repo.save(TestFactory.makePerson(name: "Demo", isDemoData: true))       // excluded

        XCTAssertEqual(repo.trackedCount(), 2)
    }

    func testTrackedCount_emptyIsZero() {
        let context = CoreDataTestStack().container.viewContext
        let repo = CoreDataPersonRepository(context: context)
        XCTAssertEqual(repo.trackedCount(), 0)
    }
}
