//
//  ContactImportServiceTests.swift
//  KeepInTouchTests
//

import XCTest
@testable import StayInTouch

final class ContactImportServiceTests: XCTestCase {

    private var stack: CoreDataStack!
    private var personRepo: CoreDataPersonRepository!
    private var cadenceRepo: CoreDataCadenceRepository!
    private var touchRepo: CoreDataTouchEventRepository!
    private var sut: ContactImportService!
    private var cadenceId: UUID!

    override func setUp() {
        super.setUp()
        stack = CoreDataStack.make(inMemory: true, shouldSeedDefaults: false)
        let context = stack.viewContext
        personRepo = CoreDataPersonRepository(context: context)
        cadenceRepo = CoreDataCadenceRepository(context: context)
        touchRepo = CoreDataTouchEventRepository(context: context)

        // Seed a default group so importSelectedContacts can find one
        cadenceId = UUID()
        let group = Cadence(
            id: cadenceId,
            name: "Monthly",
            frequencyDays: 30,
            warningDays: 7,
            colorHex: nil,
            isDefault: true,
            sortOrder: 0,
            createdAt: Date(),
            modifiedAt: Date()
        )
        try? cadenceRepo.save(group)

        sut = ContactImportService(
            personRepository: personRepo,
            touchEventRepository: touchRepo,
            coreDataStack: stack
        )
    }

    override func tearDown() {
        sut = nil
        touchRepo = nil
        cadenceRepo = nil
        personRepo = nil
        stack = nil
        super.tearDown()
    }

    // MARK: - importSelectedContacts

    func testImportSelectedContacts_savesPersonsToInjectedStack() async {
        let summary = ContactSummary(identifier: "abc-123", displayName: "Alice Smith", initials: "AS")

        await sut.importSelectedContacts([summary])

        let people = personRepo.fetchAll()
        XCTAssertEqual(people.count, 1)
        XCTAssertEqual(people.first?.displayName, "Alice Smith")
        XCTAssertEqual(people.first?.cnIdentifier, "abc-123")
    }

    func testImportSelectedContacts_assignsGroupFromGroupAssignments() async {
        let altGroupId = UUID()
        let altGroup = Cadence(
            id: altGroupId,
            name: "Weekly",
            frequencyDays: 7,
            warningDays: 2,
            colorHex: nil,
            isDefault: false,
            sortOrder: 1,
            createdAt: Date(),
            modifiedAt: Date()
        )
        try? cadenceRepo.save(altGroup)

        let summary = ContactSummary(identifier: "bob-456", displayName: "Bob Jones", initials: "BJ")

        await sut.importSelectedContacts([summary], groupAssignments: ["bob-456": altGroupId])

        let person = personRepo.fetchAll().first
        XCTAssertEqual(person?.cadenceId, altGroupId, "Should use the provided group assignment, not the default")
    }

    func testImportSelectedContacts_seedsTouchEventWhenLastTouchProvided() async {
        let summary = ContactSummary(identifier: "carol-789", displayName: "Carol White", initials: "CW")

        await sut.importSelectedContacts([summary], lastTouchSelections: ["carol-789": .thisWeek])

        let people = personRepo.fetchAll()
        XCTAssertEqual(people.count, 1)
        XCTAssertNotNil(people.first?.lastTouchAt, "lastTouchAt should be seeded for .thisWeek")

        let touchEvents = touchRepo.fetchAll(for: people.first!.id)
        XCTAssertEqual(touchEvents.count, 1, "A TouchEvent should be created when last touch is provided")
    }

    func testImportSelectedContacts_doesNotSeedTouchEventWhenCantRemember() async {
        let summary = ContactSummary(identifier: "dave-000", displayName: "Dave Brown", initials: "DB")

        await sut.importSelectedContacts([summary], lastTouchSelections: ["dave-000": .cantRemember])

        let people = personRepo.fetchAll()
        XCTAssertEqual(people.count, 1)
        XCTAssertNil(people.first?.lastTouchAt)

        let touchEvents = touchRepo.fetchAll(for: people.first!.id)
        XCTAssertEqual(touchEvents.count, 0, "No TouchEvent should be created when cantRemember is selected")
    }

    func testImportSelectedContacts_emptyInput_savesNothing() async {
        await sut.importSelectedContacts([])

        XCTAssertEqual(personRepo.fetchAll().count, 0)
    }

    func testImportSelectedContacts_setsCorrectSortOrder() async {
        let summaries = [
            ContactSummary(identifier: "a", displayName: "Alice", initials: "A"),
            ContactSummary(identifier: "b", displayName: "Bob", initials: "B"),
            ContactSummary(identifier: "c", displayName: "Carol", initials: "C"),
        ]

        await sut.importSelectedContacts(summaries)

        let people = personRepo.fetchAll().sorted { $0.sortOrder < $1.sortOrder }
        XCTAssertEqual(people.map { $0.sortOrder }, [0, 1, 2])
    }
}
