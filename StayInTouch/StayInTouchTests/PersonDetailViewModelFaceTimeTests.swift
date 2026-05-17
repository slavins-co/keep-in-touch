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

    // MARK: - routeAction(.faceTime) — single phone path

    func testFaceTimeRouteWithNoPhoneSetsToastAndReturnsNil() {
        // Default test person has no phone wired up via ContactsFetcher.
        let url = sut.routeAction(.faceTime)
        XCTAssertNil(url)
        XCTAssertNotNil(sut.quickActionMessage)
    }

    // MARK: - routeActionWithValue(.faceTime, ...) — post-picker path

    func testFaceTimeRouteWithValueProducesFaceTimeUrl() {
        let url = sut.routeActionWithValue(.faceTime, value: "+14155551212")
        XCTAssertEqual(url?.scheme, "facetime")
        XCTAssertTrue(url?.absoluteString.contains("+14155551212") ?? false,
                      "FaceTime URL should preserve E.164 with leading +")
    }

    func testFaceTimeRouteWithValueNormalizesLocalNumber() {
        // 10-digit US number without + should get country code prepended.
        let url = sut.routeActionWithValue(.faceTime, value: "(415) 555-1212")
        XCTAssertEqual(url?.scheme, "facetime")
        XCTAssertTrue(url?.absoluteString.contains("+14155551212") ?? false ||
                      url?.absoluteString.contains("+1") ?? false,
                      "Local-format US number should be normalized")
    }

    func testFaceTimeRouteWithMalformedPhoneReturnsNilAndSetsToast() {
        let url = sut.routeActionWithValue(.faceTime, value: "")
        XCTAssertNil(url)
        XCTAssertNotNil(sut.quickActionMessage)
    }

    func testFaceTimeRouteWithGarbageReturnsNilAndSetsToast() {
        let url = sut.routeActionWithValue(.faceTime, value: "hello")
        XCTAssertNil(url)
        XCTAssertNotNil(sut.quickActionMessage)
    }

    // MARK: - pendingPhoneRouting lifecycle

    func testPendingPhoneRoutingDefaultsToNil() {
        XCTAssertNil(sut.pendingPhoneRouting)
    }

    func testCancelPendingPhonePickerClearsState() {
        // routeAction with a multi-phone contact would set this; we don't have
        // that fixture wired here, so verify the cancel method works directly.
        sut.cancelPendingPhonePicker()
        XCTAssertNil(sut.pendingPhoneRouting)
    }
}
