//
//  RecentGroupsStoreTests.swift
//  KeepInTouchTests
//

import XCTest
@testable import StayInTouch

final class RecentGroupsStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!
    private var store: RecentGroupsStore!

    override func setUp() {
        super.setUp()
        suiteName = "RecentGroupsStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        store = RecentGroupsStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        store = nil
        super.tearDown()
    }

    func testLoadOnEmptyReturnsEmptyArray() {
        XCTAssertTrue(store.load().isEmpty)
    }

    func testAppendThenLoadRoundTrips() {
        let ids = [UUID(), UUID(), UUID()]
        store.append(personIds: ids)

        let loaded = store.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.personIds, ids)
    }

    func testCapacityEnforcedAtThree() {
        let groups: [[UUID]] = (0..<5).map { _ in [UUID(), UUID()] }
        for g in groups {
            store.append(personIds: g)
        }
        let loaded = store.load()
        XCTAssertEqual(loaded.count, RecentGroupsStore.capacity)
        // Most recent first.
        XCTAssertEqual(loaded.first?.personIds, groups[4])
        XCTAssertEqual(loaded.last?.personIds, groups[2])
    }

    func testAppendDedupesByMembershipSet() {
        let a = UUID()
        let b = UUID()
        store.append(personIds: [a, b])
        store.append(personIds: [b, a])  // same set, different order

        let loaded = store.load()
        XCTAssertEqual(loaded.count, 1, "Same membership set must not duplicate")
    }

    func testEmptyAppendIsNoop() {
        store.append(personIds: [])
        XCTAssertTrue(store.load().isEmpty)
    }

    func testDecodeFailureReturnsEmpty() {
        defaults.set("not valid json".data(using: .utf8), forKey: "bulkLog.recentGroups.v1")
        XCTAssertTrue(store.load().isEmpty, "Garbage payload should be ignored, not crash")
    }

    func testClearRemovesAll() {
        store.append(personIds: [UUID(), UUID()])
        XCTAssertEqual(store.load().count, 1)
        store.clear()
        XCTAssertTrue(store.load().isEmpty)
    }

    func testReAppendingSameSetPromotesItToFront() {
        let a = UUID()
        let b = UUID()
        let c = UUID()
        store.append(personIds: [a, b])
        store.append(personIds: [c])
        XCTAssertEqual(store.load().first?.personIds, [c])

        store.append(personIds: [a, b])
        XCTAssertEqual(store.load().first?.personIds, [a, b])
        XCTAssertEqual(store.load().count, 2, "Dedupe still applies — total unchanged")
    }
}
