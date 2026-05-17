//
//  PersonDetailViewModelFaceTimeTests.swift
//  KeepInTouchTests
//

import XCTest
@testable import StayInTouch

@MainActor
final class PersonDetailViewModelFaceTimeTests: XCTestCase {
    private var personRepo: MockPersonRepository!
    private var cadenceRepo: MockCadenceRepository!
    private var groupRepo: MockGroupRepository!
    private var touchRepo: MockTouchEventRepository!
    private var person: Person!
    private var sut: PersonDetailViewModel!

    override func setUp() {
        super.setUp()
        let cadenceId = UUID()
        let cadence = TestFactory.makeCadence(id: cadenceId)
        person = TestFactory.makePerson(cadenceId: cadenceId)

        personRepo = MockPersonRepository()
        personRepo.people = [person]
        cadenceRepo = MockCadenceRepository()
        cadenceRepo.cadences = [cadence]
        groupRepo = MockGroupRepository()
        touchRepo = MockTouchEventRepository()

        sut = PersonDetailViewModel(
            person: person,
            personRepository: personRepo,
            cadenceRepository: cadenceRepo,
            groupRepository: groupRepo,
            touchRepository: touchRepo
        )
    }

    // MARK: - openFaceTimeAction (single phone path)

    func testOpenFaceTimeActionWithNoPhoneSetsToastAndReturnsNil() {
        // Default test person has no phone wired up via ContactsFetcher.
        let url = sut.openFaceTimeAction()
        XCTAssertNil(url)
        XCTAssertNotNil(sut.quickActionMessage)
    }

    // MARK: - openFaceTimeActionWithValue (post-picker path)

    func testOpenFaceTimeActionWithValueProducesFaceTimeUrl() {
        let url = sut.openFaceTimeActionWithValue("+14155551212")
        XCTAssertEqual(url?.scheme, "facetime")
        XCTAssertTrue(url?.absoluteString.contains("+14155551212") ?? false,
                      "FaceTime URL should preserve E.164 with leading +")
    }

    func testOpenFaceTimeActionWithValueNormalizesLocalNumber() {
        // 10-digit US number without + should get country code prepended.
        let url = sut.openFaceTimeActionWithValue("(415) 555-1212")
        XCTAssertEqual(url?.scheme, "facetime")
        XCTAssertTrue(url?.absoluteString.contains("+14155551212") ?? false ||
                      url?.absoluteString.contains("+1") ?? false,
                      "Local-format US number should be normalized")
    }

    func testOpenFaceTimeActionWithMalformedPhoneReturnsNilAndSetsToast() {
        let url = sut.openFaceTimeActionWithValue("")
        XCTAssertNil(url)
        XCTAssertNotNil(sut.quickActionMessage)
    }

    func testOpenFaceTimeActionWithGarbageReturnsNilAndSetsToast() {
        let url = sut.openFaceTimeActionWithValue("hello")
        XCTAssertNil(url)
        XCTAssertNotNil(sut.quickActionMessage)
    }

    // MARK: - pendingFaceTime flag lifecycle (multi-phone picker hook)

    func testPendingFaceTimeDefaultsToFalse() {
        XCTAssertFalse(sut.pendingFaceTime)
    }

    func testPendingFaceTimeCanBeSetAndCleared() {
        sut.pendingFaceTime = true
        XCTAssertTrue(sut.pendingFaceTime)
        sut.pendingFaceTime = false
        XCTAssertFalse(sut.pendingFaceTime)
    }
}
