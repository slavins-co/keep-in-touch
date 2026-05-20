//
//  OpenPersonIntentTests.swift
//  KeepInTouchTests
//

import XCTest
@testable import StayInTouch

@MainActor
final class OpenPersonIntentTests: XCTestCase {
    private var harness: IntentTestHarness!

    override func setUp() {
        super.setUp()
        DeepLinkRouter.shared.pending = nil
    }

    override func tearDown() {
        harness?.tearDown()
        harness = nil
        DeepLinkRouter.shared.pending = nil
        super.tearDown()
    }

    func testPerformSetsRouterPendingToPerson() async throws {
        let person = TestFactory.makePerson(name: "Mom")
        harness = IntentTestHarness(people: [person])

        let intent = OpenPersonIntent()
        intent.person = PersonAppEntity(person: person)
        _ = try await intent.perform()

        XCTAssertEqual(DeepLinkRouter.shared.pending, .person(person.id))
    }

    func testPerformWithStaleEntityRePromptsViaNeedsValueError() async {
        harness = IntentTestHarness(people: [])

        let intent = OpenPersonIntent()
        intent.person = PersonAppEntity(
            id: UUID(),
            displayName: "Ghost",
            nickname: nil,
            lastTouchAt: nil
        )
        do {
            _ = try await intent.perform()
            XCTFail("Expected throw")
        } catch {
            // `$person.needsValueError(...)` returns an opaque
            // AppIntentError whose runtime type is internal. We can't
            // pattern-match on it; verifying that *some* error is
            // thrown (and that pending was NOT set to the stale id)
            // is enough to confirm the re-prompt path.
            XCTAssertNotEqual(DeepLinkRouter.shared.pending, .person(intent.person.id))
        }
    }
}
