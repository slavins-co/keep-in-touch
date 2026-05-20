//
//  LogTouchIntentTests.swift
//  KeepInTouchTests
//

import XCTest
@testable import StayInTouch

@MainActor
final class LogTouchIntentTests: XCTestCase {
    private var harness: IntentTestHarness!
    private var person: Person!

    override func setUp() {
        super.setUp()
        person = TestFactory.makePerson(name: "Mom")
        harness = IntentTestHarness(people: [person])
    }

    override func tearDown() {
        harness.tearDown()
        harness = nil
        super.tearDown()
    }

    func testPerformSavesTouchEventAndUpdatesPerson() async throws {
        let intent = LogTouchIntent()
        intent.person = PersonAppEntity(person: person)
        intent.method = .call
        intent.notes = "Quick chat"
        intent.date = nil

        _ = try await intent.perform()

        XCTAssertEqual(harness.touchRepo.savedEvents.count, 1)
        XCTAssertEqual(harness.touchRepo.savedEvents.first?.method, .call)
        XCTAssertEqual(harness.touchRepo.savedEvents.first?.notes, "Quick chat")
        XCTAssertEqual(harness.touchRepo.savedEvents.first?.personId, person.id)

        XCTAssertEqual(harness.personRepo.savedPersons.count, 1)
        XCTAssertEqual(harness.personRepo.savedPersons.first?.lastTouchMethod, .call)
        XCTAssertEqual(harness.personRepo.savedPersons.first?.lastTouchNotes, "Quick chat")
    }

    func testPerformWithMissingPersonThrowsPersonNotFound() async {
        let intent = LogTouchIntent()
        intent.person = PersonAppEntity(
            id: UUID(),
            displayName: "Ghost",
            nickname: nil,
            lastTouchAt: nil
        )
        intent.method = .text
        do {
            _ = try await intent.perform()
            XCTFail("Expected IntentError.personNotFound")
        } catch let error as IntentError {
            switch error {
            case .personNotFound: break
            default: XCTFail("Wrong IntentError: \(error)")
            }
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testPerformClearsSnoozeOnNewerTouch() async throws {
        let snoozed = TestFactory.makePerson(
            name: "Dad",
            snoozedUntil: Date().addingTimeInterval(86_400)
        )
        harness.tearDown()
        harness = IntentTestHarness(people: [snoozed])

        let intent = LogTouchIntent()
        intent.person = PersonAppEntity(person: snoozed)
        intent.method = .irl
        intent.notes = nil
        intent.date = nil

        _ = try await intent.perform()

        XCTAssertNil(harness.personRepo.savedPersons.last?.snoozedUntil)
    }

    func testPerformPostsPersonDidChangeNotification() async throws {
        let expectation = XCTNSNotificationExpectation(name: .personDidChange)
        expectation.expectedFulfillmentCount = 1

        let intent = LogTouchIntent()
        intent.person = PersonAppEntity(person: person)
        intent.method = .text
        intent.notes = nil
        intent.date = nil

        _ = try await intent.perform()

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testPerformTrimsWhitespaceFromNotes() async throws {
        let intent = LogTouchIntent()
        intent.person = PersonAppEntity(person: person)
        intent.method = .text
        intent.notes = "   "
        intent.date = nil

        _ = try await intent.perform()

        XCTAssertNil(harness.touchRepo.savedEvents.first?.notes)
    }

    func testPerformWithExplicitDateUsesIt() async throws {
        let past = Date().addingTimeInterval(-86_400 * 3)
        let intent = LogTouchIntent()
        intent.person = PersonAppEntity(person: person)
        intent.method = .text
        intent.notes = nil
        intent.date = past

        _ = try await intent.perform()

        XCTAssertEqual(harness.touchRepo.savedEvents.first?.at, past)
    }
}
