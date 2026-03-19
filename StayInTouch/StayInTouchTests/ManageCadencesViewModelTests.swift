//
//  ManageCadencesViewModelTests.swift
//  KeepInTouchTests
//
//  Created by Claude on 2/27/26.
//

import XCTest
@testable import StayInTouch

@MainActor
final class ManageCadencesViewModelTests: XCTestCase {
    private var cadenceRepo: MockCadenceRepository!
    private var personRepo: MockPersonRepository!
    private var sut: ManageCadencesViewModel!

    private var defaultCadence: Cadence!
    private var customGroup: Cadence!

    override func setUp() {
        super.setUp()
        cadenceRepo = MockCadenceRepository()
        personRepo = MockPersonRepository()

        defaultCadence = TestFactory.makeCadence(id: UUID(), name: "Weekly", isDefault: true)
        customGroup = TestFactory.makeCadence(id: UUID(), name: "Monthly", frequencyDays: 30, isDefault: false)

        cadenceRepo.cadences = [defaultCadence, customGroup]

        sut = ManageCadencesViewModel(
            cadenceRepository: cadenceRepo,
            personRepository: personRepo
        )
    }

    // MARK: - Cascade Delete: Cadence → People Reassignment

    func testDeleteGroupReassignsPeopleToDefaultGroup() {
        let person1 = TestFactory.makePerson(name: "Alice", cadenceId: customGroup.id)
        let person2 = TestFactory.makePerson(name: "Bob", cadenceId: customGroup.id)
        personRepo.people = [person1, person2]

        sut.delete(cadence: customGroup)

        let savedPeople = personRepo.savedPersons
        let reassigned = savedPeople.filter { $0.cadenceId == defaultCadence.id }
        XCTAssertEqual(reassigned.count, 2, "Both people should be reassigned to the default group")
    }

    func testDeleteGroupCallsRepositoryDelete() {
        sut.delete(cadence: customGroup)

        XCTAssertFalse(cadenceRepo.cadences.contains(where: { $0.id == customGroup.id }),
                       "Cadence should be removed from repository")
    }

    func testDeleteGroupUsesBatchSave() {
        let person1 = TestFactory.makePerson(name: "Alice", cadenceId: customGroup.id)
        let person2 = TestFactory.makePerson(name: "Bob", cadenceId: customGroup.id)
        personRepo.people = [person1, person2]

        sut.delete(cadence: customGroup)

        XCTAssertEqual(personRepo.batchSaveCallCount, 1,
                       "Should use single batchSave instead of individual saves")
        let reassigned = personRepo.savedPersons.filter { $0.cadenceId == defaultCadence.id }
        XCTAssertEqual(reassigned.count, 2,
                       "Both people should be reassigned via batch save")
    }

    func testDeleteGroupWithNoPeopleJustDeletes() {
        personRepo.people = []

        sut.delete(cadence: customGroup)

        XCTAssertTrue(personRepo.savedPersons.isEmpty, "No people should be saved when none exist in the group")
        XCTAssertFalse(cadenceRepo.cadences.contains(where: { $0.id == customGroup.id }),
                       "Cadence should still be deleted")
    }
}
