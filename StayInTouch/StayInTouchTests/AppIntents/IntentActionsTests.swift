//
//  IntentActionsTests.swift
//  KeepInTouchTests
//
//  Tests the IntentActions facade directly so we can verify the analytics
//  side effects that LogTouchIntent triggers via the default-arg facade
//  but can't reach into from the @Parameter-driven Intent type.
//

import XCTest
@testable import StayInTouch

@MainActor
final class IntentActionsTests: XCTestCase {
    private var harness: IntentTestHarness!

    override func tearDown() {
        harness?.tearDown()
        harness = nil
        super.tearDown()
    }

    func testLogTouchTracksAnalyticsWithSiriSource() throws {
        let person = TestFactory.makePerson(name: "Mom")
        harness = IntentTestHarness(people: [person])

        var trackedSignals: [(String, [String: String])] = []
        let actions = IntentActions(
            dependencies: harness.container.dependencies,
            trackAnalytics: { signal, params in
                trackedSignals.append((signal, params))
            }
        )

        _ = try actions.logTouch(
            personId: person.id,
            method: .call,
            notes: nil,
            date: Date()
        )

        XCTAssertEqual(trackedSignals.count, 1)
        XCTAssertEqual(trackedSignals.first?.0, "connection.logged")
        XCTAssertEqual(trackedSignals.first?.1["source"], "siri")
        XCTAssertEqual(trackedSignals.first?.1["method"], "Call")
    }

    func testLogTouchDoesNotTrackOnPersonNotFound() {
        harness = IntentTestHarness(people: [])

        var trackedSignals: [(String, [String: String])] = []
        let actions = IntentActions(
            dependencies: harness.container.dependencies,
            trackAnalytics: { signal, params in
                trackedSignals.append((signal, params))
            }
        )

        do {
            _ = try actions.logTouch(
                personId: UUID(),
                method: .text,
                notes: nil,
                date: Date()
            )
            XCTFail("Expected throw")
        } catch {
            // Expected
        }
        XCTAssertEqual(trackedSignals.count, 0, "Analytics should not fire when person lookup fails")
    }
}
