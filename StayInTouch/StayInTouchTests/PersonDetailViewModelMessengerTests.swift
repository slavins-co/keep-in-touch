//
//  PersonDetailViewModelMessengerTests.swift
//  KeepInTouchTests
//

import XCTest
@testable import StayInTouch

@MainActor
final class PersonDetailViewModelMessengerTests: XCTestCase {
    private var personRepo: MockPersonRepository!
    private var cadenceRepo: MockCadenceRepository!
    private var groupRepo: MockGroupRepository!
    private var touchRepo: MockTouchEventRepository!
    private var availability: FakeMessengerAvailability!
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
        availability = FakeMessengerAvailability(installed: [.iMessage, .whatsapp])

        sut = PersonDetailViewModel(
            person: person,
            personRepository: personRepo,
            cadenceRepository: cadenceRepo,
            groupRepository: groupRepo,
            touchRepository: touchRepo,
            messengerAvailability: availability
        )
    }

    // MARK: - resolvedMessenger

    func testResolvedMessengerFallsBackToiMessageWhenNoPreference() {
        XCTAssertEqual(sut.resolvedMessenger, .iMessage)
    }

    func testResolvedMessengerReturnsSavedPreference() {
        var updated = person!
        updated.preferredMessenger = .whatsapp
        personRepo.people = [updated]
        sut.load()

        XCTAssertEqual(sut.resolvedMessenger, .whatsapp)
    }

    // MARK: - availableMessengers

    func testAvailableMessengersReflectsInstalledList() {
        XCTAssertEqual(Set(sut.availableMessengers), Set([.iMessage, .whatsapp]))
    }

    func testAvailableMessengersExcludesUninstalled() {
        // availableMessengers is cached at init, so build a fresh VM with the
        // desired availability rather than mutating the fake post-init.
        let onlyiMessage = FakeMessengerAvailability(installed: [.iMessage])
        let vm = PersonDetailViewModel(
            person: person,
            personRepository: personRepo,
            cadenceRepository: cadenceRepo,
            groupRepository: groupRepo,
            touchRepository: touchRepo,
            messengerAvailability: onlyiMessage
        )
        XCTAssertEqual(vm.availableMessengers, [.iMessage])
    }

    // MARK: - setPreferredMessenger

    func testSetPreferredMessengerToWhatsAppPersists() {
        sut.setPreferredMessenger(.whatsapp)
        XCTAssertEqual(sut.person.preferredMessenger, .whatsapp)
        XCTAssertEqual(personRepo.savedPersons.last?.preferredMessenger, .whatsapp)
    }

    func testSetPreferredMessengerToiMessageStoresNil() {
        // First set to whatsapp, then back to iMessage — should clear to nil.
        sut.setPreferredMessenger(.whatsapp)
        sut.setPreferredMessenger(.iMessage)

        XCTAssertNil(sut.person.preferredMessenger,
                     "iMessage should store nil so a future global default can flip behavior")
    }

    func testSetSamePreferenceDoesNotTriggerSave() {
        // person starts with nil; setting iMessage (which stores as nil) shouldn't save.
        let beforeSaves = personRepo.savedPersons.count
        sut.setPreferredMessenger(.iMessage)
        XCTAssertEqual(personRepo.savedPersons.count, beforeSaves,
                       "Setting the same effective preference should be a no-op")
    }

    // MARK: - handleFailedMessengerOpen self-heal

    func testFailedSignalOpenClearsStickyPreferenceAndShowsToast() {
        var updated = person!
        updated.preferredMessenger = .signal
        personRepo.people = [updated]
        sut.load()

        sut.handleFailedMessengerOpen(messenger: .signal)

        XCTAssertNil(sut.person.preferredMessenger,
                     "Failed sticky open should self-heal by clearing the preference")
        XCTAssertNotNil(sut.quickActionMessage)
        XCTAssertTrue(sut.quickActionMessage?.contains("Signal") ?? false)
    }

    func testFailedOpenWithNoStickyPreferenceJustShowsToast() {
        // No preference set; just a generic failure.
        sut.handleFailedMessengerOpen(messenger: .iMessage)

        XCTAssertNil(sut.person.preferredMessenger)
        XCTAssertNotNil(sut.quickActionMessage)
    }

    // MARK: - routeAction / routeActionWithValue routing

    func testMessageRouteDefaultsToSmsWhenNoPreferenceSet() {
        let url = sut.routeActionWithValue(.message(explicit: nil), value: "+14155551212")
        XCTAssertEqual(url?.scheme, "sms", "Default routing should produce sms: when preference is nil")
    }

    func testMessageRouteWithExplicitWhatsAppRoutesToWaMe() {
        let url = sut.routeActionWithValue(.message(explicit: .whatsapp), value: "+14155551212")
        XCTAssertEqual(url?.host, "wa.me")
    }

    func testMessageRouteRespectsSavedPreference() {
        var updated = person!
        updated.preferredMessenger = .whatsapp
        personRepo.people = [updated]
        sut.load()

        let url = sut.routeActionWithValue(.message(explicit: nil), value: "+14155551212")
        XCTAssertEqual(url?.host, "wa.me",
                       "Saved preference should drive routing when no explicit override")
    }

    func testCallRouteAlwaysProducesTelScheme() {
        let url = sut.routeActionWithValue(.call, value: "+14155551212")
        XCTAssertEqual(url?.scheme, "tel",
                       "Call should always route to tel: regardless of messenger preference")
    }

    func testMessageRouteWithMalformedPhoneSetsToast() {
        let url = sut.routeActionWithValue(.message(explicit: .whatsapp), value: "")
        XCTAssertNil(url)
        XCTAssertNotNil(sut.quickActionMessage)
    }

    // MARK: - PhoneRouting.resolvedTouchMethod mapping

    func testResolvedTouchMethodForCallAndFaceTimeIgnoresDefaultMessenger() {
        // .call and .faceTime have a fixed TouchMethod regardless of default.
        XCTAssertEqual(
            PersonDetailViewModel.PhoneRouting.call.resolvedTouchMethod(defaultMessenger: .whatsapp),
            .call
        )
        XCTAssertEqual(
            PersonDetailViewModel.PhoneRouting.faceTime.resolvedTouchMethod(defaultMessenger: .signal),
            .facetime
        )
    }

    func testResolvedTouchMethodForExplicitMessengerLogsTextMedium() {
        // #299: TouchMethod collapsed to medium-only. WhatsApp and Signal are
        // text-medium apps — they route correctly via PreferredMessenger but
        // log as .text. Per-touch app identity is no longer recorded; the
        // per-contact preference lives on Person.preferredMessenger.
        XCTAssertEqual(
            PersonDetailViewModel.PhoneRouting.message(explicit: .whatsapp)
                .resolvedTouchMethod(defaultMessenger: .iMessage),
            .text
        )
        XCTAssertEqual(
            PersonDetailViewModel.PhoneRouting.message(explicit: .signal)
                .resolvedTouchMethod(defaultMessenger: .whatsapp),
            .text
        )
    }

    /// Sticky messenger preferences (WhatsApp/Signal) still ROUTE to the
    /// correct app on single-tap, but the logged TouchMethod is .text for
    /// all text-medium apps after #299. The which-app signal is preserved
    /// on Person.preferredMessenger, not duplicated on each TouchEvent.
    func testResolvedTouchMethodForImplicitMessengerAlwaysTextMedium() {
        XCTAssertEqual(
            PersonDetailViewModel.PhoneRouting.message(explicit: nil)
                .resolvedTouchMethod(defaultMessenger: .iMessage),
            .text
        )
        XCTAssertEqual(
            PersonDetailViewModel.PhoneRouting.message(explicit: nil)
                .resolvedTouchMethod(defaultMessenger: .whatsapp),
            .text,
            "Sticky WhatsApp preference routes to WhatsApp app but logs as .text medium (#299)"
        )
        XCTAssertEqual(
            PersonDetailViewModel.PhoneRouting.message(explicit: nil)
                .resolvedTouchMethod(defaultMessenger: .signal),
            .text,
            "Sticky Signal preference routes to Signal app but logs as .text medium (#299)"
        )
    }
}

// MARK: - Test double

private final class FakeMessengerAvailability: MessengerAvailabilityChecking {
    var installed: Set<PreferredMessenger>

    init(installed: Set<PreferredMessenger>) {
        self.installed = installed
    }

    func isAvailable(_ messenger: PreferredMessenger) -> Bool {
        installed.contains(messenger)
    }
}
