//
//  PersonDetailViewModelTests.swift
//  KeepInTouchTests
//
//  Created by Codex on 2/24/26.
//

import XCTest
@testable import StayInTouch

@MainActor
final class PersonDetailViewModelTests: XCTestCase {
    private var personRepo: MockPersonRepository!
    private var cadenceRepo: MockCadenceRepository!
    private var groupRepo: MockGroupRepository!
    private var touchRepo: MockTouchEventRepository!
    private var group: Cadence!
    private var person: Person!
    private var sut: PersonDetailViewModel!

    override func setUp() {
        super.setUp()
        let cadenceId = UUID()
        group = TestFactory.makeCadence(id: cadenceId)
        person = TestFactory.makePerson(cadenceId: cadenceId)

        personRepo = MockPersonRepository()
        personRepo.people = [person]
        cadenceRepo = MockCadenceRepository()
        cadenceRepo.groups = [group]
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

    // MARK: - Load

    func testLoadPopulatesGroupsTagsEvents() {
        let group = TestFactory.makeGroup()
        groupRepo.groups = [group]
        let touch = TestFactory.makeTouchEvent(personId: person.id)
        touchRepo.events = [touch]

        sut.load()

        XCTAssertEqual(sut.cadences.count, 1)
        XCTAssertEqual(sut.groups.count, 1)
        XCTAssertEqual(sut.availableGroups.count, 1)
        XCTAssertEqual(sut.touchEvents.count, 1)
    }

    // MARK: - Touch Logging

    func testLogTouchCreatesTouchEvent() {
        let fixedDate = Date()

        sut.logTouch(method: .call, notes: "Caught up", date: fixedDate)

        XCTAssertEqual(touchRepo.savedEvents.count, 1)
        XCTAssertEqual(touchRepo.savedEvents.first?.method, .call)
        XCTAssertEqual(touchRepo.savedEvents.first?.notes, "Caught up")
        XCTAssertEqual(sut.person.lastTouchAt, fixedDate)
        XCTAssertEqual(sut.person.lastTouchMethod, .call)
        XCTAssertEqual(sut.person.lastTouchNotes, "Caught up")
        XCTAssertEqual(sut.touchEvents.count, 1)
    }

    func testLogTouchClearsSnooze() {
        let cadenceId = group.id
        let snoozedPerson = TestFactory.makePerson(
            cadenceId: cadenceId,
            snoozedUntil: Date().addingTimeInterval(86400)
        )
        personRepo.people = [snoozedPerson]

        let vm = PersonDetailViewModel(
            person: snoozedPerson,
            personRepository: personRepo,
            cadenceRepository: cadenceRepo,
            groupRepository: groupRepo,
            touchRepository: touchRepo
        )

        vm.logTouch(method: .text, notes: nil, date: Date())

        XCTAssertNil(vm.person.snoozedUntil)
    }

    func testLogTouchWithTimeOfDay() {
        sut.logTouch(method: .irl, notes: nil, date: Date(), timeOfDay: .evening)

        XCTAssertEqual(touchRepo.savedEvents.first?.timeOfDay, .evening)
    }

    func testUpdateTouchModifiesExistingEvent() {
        let touch = TestFactory.makeTouchEvent(personId: person.id, method: .call, notes: "Original")
        touchRepo.events = [touch]
        sut.load()

        sut.updateTouch(touch, method: .text, notes: "Updated")

        let updated = touchRepo.events.first { $0.id == touch.id }
        XCTAssertEqual(updated?.method, .text)
        XCTAssertEqual(updated?.notes, "Updated")
    }

    func testUpdateMostRecentTouchUpdatesPersonLastTouch() {
        let touch = TestFactory.makeTouchEvent(personId: person.id, at: Date(), method: .call)
        touchRepo.events = [touch]
        sut.load()

        sut.updateTouch(touch, method: .email, notes: "Email follow-up")

        XCTAssertEqual(sut.person.lastTouchMethod, .email)
        XCTAssertEqual(sut.person.lastTouchNotes, "Email follow-up")
    }

    func testUpdateOlderTouchDoesNotChangePersonLastTouch() {
        let now = Date()
        let olderTouch = TestFactory.makeTouchEvent(
            personId: person.id,
            at: now.addingTimeInterval(-86400),
            method: .call
        )
        let newerTouch = TestFactory.makeTouchEvent(
            personId: person.id,
            at: now,
            method: .text
        )
        touchRepo.events = [olderTouch, newerTouch]

        // Need to set person's lastTouch to the newer touch first
        sut.logTouch(method: .text, notes: nil, date: now)

        // Clear saved events and reset
        touchRepo.savedEvents = []
        touchRepo.events = [olderTouch, newerTouch]
        sut.load()

        sut.updateTouch(olderTouch, method: .irl, notes: "Changed older")

        // Person's lastTouch should still reflect the newer touch
        XCTAssertEqual(sut.person.lastTouchMethod, .text)
    }

    func testDeleteTouchRollsBackToOlderTouch() {
        let now = Date()
        let olderDate = now.addingTimeInterval(-86400)
        let olderTouch = TestFactory.makeTouchEvent(
            personId: person.id,
            at: olderDate,
            method: .call,
            notes: "Older"
        )
        let newerTouch = TestFactory.makeTouchEvent(
            personId: person.id,
            at: now,
            method: .text,
            notes: "Newer"
        )
        touchRepo.events = [olderTouch, newerTouch]
        sut.load()

        sut.deleteTouch(newerTouch)

        XCTAssertEqual(sut.person.lastTouchAt, olderDate)
        XCTAssertEqual(sut.person.lastTouchMethod, .call)
        XCTAssertEqual(sut.person.lastTouchNotes, "Older")
        XCTAssertEqual(sut.touchEvents.count, 1)
    }

    func testDeleteOnlyTouchClearsPersonLastTouch() {
        let touch = TestFactory.makeTouchEvent(personId: person.id)
        touchRepo.events = [touch]
        sut.load()

        sut.deleteTouch(touch)

        XCTAssertNil(sut.person.lastTouchAt)
        XCTAssertNil(sut.person.lastTouchMethod)
        XCTAssertNil(sut.person.lastTouchNotes)
        XCTAssertTrue(sut.touchEvents.isEmpty)
    }

    // MARK: - Cadence Assignment

    func testChangeGroupUpdatesPerson() {
        let newGroup = TestFactory.makeCadence(name: "Monthly", frequencyDays: 30)
        cadenceRepo.groups.append(newGroup)

        sut.changeCadence(to: newGroup.id)

        XCTAssertEqual(sut.person.cadenceId, newGroup.id)
        XCTAssertEqual(sut.group?.id, newGroup.id)
    }

    func testChangeGroupSetsGroupAddedAt() {
        let newGroup = TestFactory.makeCadence(name: "Monthly", frequencyDays: 30)
        cadenceRepo.groups.append(newGroup)

        // Create person without cadenceAddedAt
        var freshPerson = TestFactory.makePerson(cadenceId: group.id)
        freshPerson.cadenceAddedAt = nil
        personRepo.people = [freshPerson]

        let vm = PersonDetailViewModel(
            person: freshPerson,
            personRepository: personRepo,
            cadenceRepository: cadenceRepo,
            groupRepository: groupRepo,
            touchRepository: touchRepo
        )

        vm.changeCadence(to: newGroup.id)

        XCTAssertNotNil(vm.person.cadenceAddedAt)
    }

    // MARK: - Contact Deletion

    func testDeletePersonCallsRepositoryDelete() {
        sut.deletePerson()

        XCTAssertTrue(personRepo.deletedIds.contains(person.id))
    }

    func testDeletePersonPostsNotification() {
        let personId = person.id
        let expectation = expectation(forNotification: .personDidChange, object: nil) { notification in
            notification.object as? UUID == personId
        }

        sut.deletePerson()

        wait(for: [expectation], timeout: 1.0)
    }

    func testDeletePersonCascadesDeletesTouchEvents() {
        let event1 = TestFactory.makeTouchEvent(personId: person.id, method: .call)
        let event2 = TestFactory.makeTouchEvent(personId: person.id, method: .text)
        let event3 = TestFactory.makeTouchEvent(personId: person.id, method: .email)
        touchRepo.events = [event1, event2, event3]

        sut.deletePerson()

        XCTAssertTrue(touchRepo.deletedIds.contains(event1.id))
        XCTAssertTrue(touchRepo.deletedIds.contains(event2.id))
        XCTAssertTrue(touchRepo.deletedIds.contains(event3.id))
        XCTAssertEqual(touchRepo.deletedIds.count, 3, "All 3 touch events should be cascade deleted")
        XCTAssertTrue(personRepo.deletedIds.contains(person.id), "Person should also be deleted")
    }

    func testDeletePersonWithNoTouchEventsStillDeletesPerson() {
        touchRepo.events = []

        sut.deletePerson()

        XCTAssertTrue(touchRepo.deletedIds.isEmpty, "No touch events to delete")
        XCTAssertTrue(personRepo.deletedIds.contains(person.id), "Person should still be deleted")
    }

    // MARK: - Tags

    func testAddTagAppendsToTagIds() {
        let group = TestFactory.makeGroup()
        groupRepo.groups = [group]
        sut.load()

        sut.addGroup(group)

        XCTAssertTrue(sut.person.groupIds.contains(group.id))
    }

    func testAddDuplicateTagIsNoOp() {
        let group = TestFactory.makeGroup()
        groupRepo.groups = [group]
        sut.load()

        sut.addGroup(group)
        sut.addGroup(group)

        XCTAssertEqual(sut.person.groupIds.filter { $0 == group.id }.count, 1)
    }

    func testRemoveTagRemovesFromTagIds() {
        let group = TestFactory.makeGroup()
        groupRepo.groups = [group]
        person.groupIds = [group.id]
        personRepo.people = [person]
        sut = PersonDetailViewModel(
            person: person,
            personRepository: personRepo,
            cadenceRepository: cadenceRepo,
            groupRepository: groupRepo,
            touchRepository: touchRepo
        )

        sut.removeGroup(group)

        XCTAssertFalse(sut.person.groupIds.contains(group.id))
    }

    // MARK: - Pause / Mute

    func testTogglePauseFlipsPausedState() {
        XCTAssertFalse(sut.person.isPaused)

        sut.togglePause()
        XCTAssertTrue(sut.person.isPaused)

        sut.togglePause()
        XCTAssertFalse(sut.person.isPaused)
    }

    func testSetNotificationsMuted() {
        sut.setNotificationsMuted(true)
        XCTAssertTrue(sut.person.notificationsMuted)

        sut.setNotificationsMuted(false)
        XCTAssertFalse(sut.person.notificationsMuted)
    }

    // MARK: - Snooze

    func testSnoozeAndClearSnooze() {
        let futureDate = Date().addingTimeInterval(86400 * 7)

        sut.snooze(until: futureDate)
        XCTAssertEqual(sut.person.snoozedUntil, futureDate)

        sut.clearSnooze()
        XCTAssertNil(sut.person.snoozedUntil)
    }

    // MARK: - Resume

    func testResumeAndUpdateLastTouchLogsEvent() {
        let resumeDate = Date()
        let pausedPerson = TestFactory.makePerson(cadenceId: group.id, isPaused: true)
        personRepo.people = [pausedPerson]

        let vm = PersonDetailViewModel(
            person: pausedPerson,
            personRepository: personRepo,
            cadenceRepository: cadenceRepo,
            groupRepository: groupRepo,
            touchRepository: touchRepo
        )

        vm.resumeAndUpdateLastTouch(date: resumeDate)

        XCTAssertFalse(vm.person.isPaused)
        XCTAssertEqual(vm.person.lastTouchAt, resumeDate)
        XCTAssertEqual(vm.person.lastTouchMethod, .other)
        XCTAssertEqual(vm.person.lastTouchNotes, "Resumed tracking")
        XCTAssertEqual(touchRepo.savedEvents.count, 1)
    }

    // MARK: - Birthday

    func testSetBirthdayPersistsAndPublishes() {
        let birthday = Birthday(month: 3, day: 15, year: nil)
        sut.setBirthday(birthday)

        XCTAssertEqual(sut.person.birthday, birthday)
        XCTAssertEqual(personRepo.savedPersons.last?.birthday, birthday)
    }

    func testClearBirthdayRemovesIt() {
        let personWithBirthday = TestFactory.makePerson(cadenceId: group.id, birthday: Birthday(month: 7, day: 4, year: nil))
        personRepo.people = [personWithBirthday]

        let vm = PersonDetailViewModel(
            person: personWithBirthday,
            personRepository: personRepo,
            cadenceRepository: cadenceRepo,
            groupRepository: groupRepo,
            touchRepository: touchRepo
        )

        vm.setBirthday(nil)
        XCTAssertNil(vm.person.birthday)
    }

    func testDisplayBirthdayPrefersManualOverride() {
        let manual = Birthday(month: 1, day: 1, year: nil)
        let contact = Birthday(month: 7, day: 4, year: 1990)
        let personWithBirthday = TestFactory.makePerson(cadenceId: group.id, birthday: manual)
        personRepo.people = [personWithBirthday]

        let vm = PersonDetailViewModel(
            person: personWithBirthday,
            personRepository: personRepo,
            cadenceRepository: cadenceRepo,
            groupRepository: groupRepo,
            touchRepository: touchRepo
        )
        vm.contactBirthday = contact

        XCTAssertEqual(vm.displayBirthday, manual)
    }

    func testDisplayBirthdayFallsBackToContactBirthday() {
        XCTAssertNil(sut.person.birthday)

        let contactBday = Birthday(month: 7, day: 4, year: 1990)
        sut.contactBirthday = contactBday

        XCTAssertEqual(sut.displayBirthday, contactBday)
    }

    func testDisplayBirthdayIsNilWhenNeitherSourceSet() {
        XCTAssertNil(sut.person.birthday)
        XCTAssertNil(sut.contactBirthday)
        XCTAssertNil(sut.displayBirthday)
    }

    // MARK: - Load Refreshes Person From Repository

    func testLoadRefreshesPersonFromRepository() {
        // Simulate Fresh Start: person was overdue, then an external
        // process (executeFreshStart) updated lastTouchAt in the repo.
        let overduePerson = TestFactory.makePerson(
            cadenceId: group.id,
            lastTouchAt: Calendar.current.date(byAdding: .day, value: -30, to: Date())
        )
        personRepo.people = [overduePerson]

        let vm = PersonDetailViewModel(
            person: overduePerson,
            personRepository: personRepo,
            cadenceRepository: cadenceRepo,
            groupRepository: groupRepo,
            touchRepository: touchRepo
        )

        // Verify initially overdue
        let statusBefore = FrequencyCalculator().status(for: vm.person, in: [group])
        XCTAssertEqual(statusBefore, .overdue)

        // External update (simulates executeFreshStart's batchSave)
        var refreshed = overduePerson
        refreshed.lastTouchAt = Date()
        refreshed.modifiedAt = Date()
        personRepo.people = [refreshed]

        // Simulate .onAppear calling load()
        vm.load()

        let statusAfter = FrequencyCalculator().status(for: vm.person, in: [group])
        XCTAssertEqual(statusAfter, .onTrack,
            "After load(), person should reflect the updated lastTouchAt from the repository")
    }
}
