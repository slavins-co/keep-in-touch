//
//  PersonAppEntityQueryTests.swift
//  KeepInTouchTests
//

import XCTest
@testable import StayInTouch

@MainActor
final class PersonAppEntityQueryTests: XCTestCase {
    private var harness: IntentTestHarness!

    override func tearDown() {
        harness?.tearDown()
        harness = nil
        super.tearDown()
    }

    func testEntitiesForIDsReturnsMatchingPeople() async throws {
        let alice = TestFactory.makePerson(name: "Alice")
        let bob = TestFactory.makePerson(name: "Bob")
        harness = IntentTestHarness(people: [alice, bob])

        let results = try await PersonAppEntityQuery().entities(for: [alice.id, bob.id])
        XCTAssertEqual(Set(results.map(\.id)), Set([alice.id, bob.id]))
    }

    func testEntitiesForIDsSkipsUnknownIDs() async throws {
        let alice = TestFactory.makePerson(name: "Alice")
        harness = IntentTestHarness(people: [alice])

        let unknown = UUID()
        let results = try await PersonAppEntityQuery().entities(for: [alice.id, unknown])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, alice.id)
    }

    func testEntitiesMatchingFiltersByDisplayName() async throws {
        let mom = TestFactory.makePerson(name: "Mom")
        let other = TestFactory.makePerson(name: "Boss")
        harness = IntentTestHarness(people: [mom, other])

        let results = try await PersonAppEntityQuery().entities(matching: "mom")
        XCTAssertEqual(results.map(\.displayName), ["Mom"])
    }

    func testEntitiesMatchingIsCaseInsensitive() async throws {
        let alice = TestFactory.makePerson(name: "Alice")
        harness = IntentTestHarness(people: [alice])

        let results = try await PersonAppEntityQuery().entities(matching: "ALICE")
        XCTAssertEqual(results.count, 1)
    }

    func testEntitiesMatchingEmptyStringReturnsNothing() async throws {
        let alice = TestFactory.makePerson(name: "Alice")
        harness = IntentTestHarness(people: [alice])

        let results = try await PersonAppEntityQuery().entities(matching: "   ")
        XCTAssertEqual(results.count, 0)
    }

    func testSuggestedEntitiesSortsByLastTouchDescending() async throws {
        let now = Date()
        let recent = TestFactory.makePerson(
            name: "Recent",
            lastTouchAt: now.addingTimeInterval(-3600)
        )
        let stale = TestFactory.makePerson(
            name: "Stale",
            lastTouchAt: now.addingTimeInterval(-86_400 * 10)
        )
        let never = TestFactory.makePerson(name: "Never")
        harness = IntentTestHarness(people: [stale, recent, never])

        let results = try await PersonAppEntityQuery().suggestedEntities()
        XCTAssertEqual(results.map(\.displayName), ["Recent", "Stale", "Never"])
    }
}
