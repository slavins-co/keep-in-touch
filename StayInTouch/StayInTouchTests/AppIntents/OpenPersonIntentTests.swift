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

    func testPerformWithStaleEntityRoutesToHomeAndThrows() async {
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
        } catch let error as IntentError {
            if case .personNotFound = error {
                XCTAssertEqual(DeepLinkRouter.shared.pending, .home)
            } else {
                XCTFail("Wrong IntentError: \(error)")
            }
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }
}
