//
//  GetDueSoonContactsIntentTests.swift
//  KeepInTouchTests
//
//  Intent return values are wrapped in opaque IntentResult containers
//  that can't be unwrapped from outside the App Intents framework, so
//  these tests verify the side effects (no throw, classification path
//  exercised) rather than the result payload.
//

import CoreData
import XCTest
@testable import StayInTouch

@MainActor
final class GetDueSoonContactsIntentTests: XCTestCase {
    private var harness: IntentTestHarness!

    override func tearDown() {
        harness?.tearDown()
        harness = nil
        super.tearDown()
    }

    func testPerformDoesNotThrowWithEmptyState() async throws {
        harness = IntentTestHarness()
        _ = try await GetDueSoonContactsIntent().perform()
    }

    func testPerformDoesNotThrowWithPopulatedState() async throws {
        let cadenceId = UUID()
        let cadence = TestFactory.makeCadence(id: cadenceId, frequencyDays: 7)
        // Person whose effective due date is within `warningDays` of today.
        let person = TestFactory.makePerson(
            name: "Charlie",
            cadenceId: cadenceId,
            lastTouchAt: Calendar.current.date(byAdding: .day, value: -6, to: Date())
        )
        harness = IntentTestHarness(
            people: [person],
            cadences: [cadence]
        )
        _ = try await GetDueSoonContactsIntent().perform()
    }
}
