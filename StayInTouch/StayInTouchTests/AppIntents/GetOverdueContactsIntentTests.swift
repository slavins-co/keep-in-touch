//
//  GetOverdueContactsIntentTests.swift
//  KeepInTouchTests
//
//  Intent return values are wrapped in opaque IntentResult containers
//  that can't be unwrapped from outside the App Intents framework, so
//  these tests verify the side effects (repository call, no throw)
//  rather than the result payload.
//

import XCTest
@testable import StayInTouch

@MainActor
final class GetOverdueContactsIntentTests: XCTestCase {
    private var harness: IntentTestHarness!

    override func tearDown() {
        harness?.tearDown()
        harness = nil
        super.tearDown()
    }

    func testPerformCallsFetchOverdueOnRepository() async throws {
        let alice = TestFactory.makePerson(name: "Alice")
        let bob = TestFactory.makePerson(name: "Bob")
        harness = IntentTestHarness(people: [alice, bob], overdue: [alice, bob])

        _ = try await GetOverdueContactsIntent().perform()
        XCTAssertEqual(harness.personRepo.fetchOverdueCallCount, 1)
    }

    func testPerformDoesNotThrowWhenNoneOverdue() async throws {
        let alice = TestFactory.makePerson(name: "Alice")
        harness = IntentTestHarness(people: [alice], overdue: [])
        _ = try await GetOverdueContactsIntent().perform()
        XCTAssertEqual(harness.personRepo.fetchOverdueCallCount, 1)
    }

    func testPerformWithNoTrackedPeople() async throws {
        harness = IntentTestHarness(people: [], overdue: [])
        _ = try await GetOverdueContactsIntent().perform()
        XCTAssertEqual(harness.personRepo.fetchOverdueCallCount, 1)
    }
}
