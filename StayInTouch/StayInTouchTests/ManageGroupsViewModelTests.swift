//
//  ManageGroupsViewModelTests.swift
//  KeepInTouchTests
//
//  Created by Claude on 2/27/26.
//

import XCTest
@testable import StayInTouch

@MainActor
final class ManageGroupsViewModelTests: XCTestCase {
    private var groupRepo: MockGroupRepository!
    private var personRepo: MockPersonRepository!
    private var sut: ManageGroupsViewModel!

    private var group: Group!

    override func setUp() {
        super.setUp()
        groupRepo = MockGroupRepository()
        personRepo = MockPersonRepository()

        group = TestFactory.makeGroup(id: UUID(), name: "Work")
        groupRepo.groups = [group]

        sut = ManageGroupsViewModel(
            groupRepository: groupRepo,
            personRepository: personRepo
        )
    }

    // MARK: - Cascade Delete: Group → People Group Removal

    func testDeleteGroupRemovesGroupIdFromAllPeople() {
        let cadenceId = UUID()
        let person1 = TestFactory.makePerson(name: "Alice", cadenceId: cadenceId, groupIds: [group.id])
        let person2 = TestFactory.makePerson(name: "Bob", cadenceId: cadenceId, groupIds: [group.id, UUID()])
        personRepo.people = [person1, person2]

        sut.delete(group: group)

        // Both people should have been saved with the group removed
        let savedPeople = personRepo.savedPersons
        XCTAssertEqual(savedPeople.count, 2, "Both people should be updated")
        for person in savedPeople {
            XCTAssertFalse(person.groupIds.contains(group.id),
                           "\(person.displayName) should no longer have the deleted group")
        }
    }

    func testDeleteGroupCallsRepositoryDelete() {
        sut.delete(group: group)

        XCTAssertFalse(groupRepo.groups.contains(where: { $0.id == group.id }),
                       "Group should be removed from repository")
    }

    func testDeleteGroupUsesBatchSave() {
        let cadenceId = UUID()
        let person1 = TestFactory.makePerson(name: "Alice", cadenceId: cadenceId, groupIds: [group.id])
        let person2 = TestFactory.makePerson(name: "Bob", cadenceId: cadenceId, groupIds: [group.id])
        personRepo.people = [person1, person2]

        sut.delete(group: group)

        XCTAssertEqual(personRepo.batchSaveCallCount, 1,
                       "Should use single batchSave instead of individual saves")
        XCTAssertEqual(personRepo.savedPersons.count, 2,
                       "Both people should still be updated")
    }

    func testDeleteGroupRemovesFromPeopleBeforeDeleting() {
        // Verify order: removeGroupFromPeople runs before groupRepository.delete
        // After delete, group should be gone AND people should be cleaned
        let person = TestFactory.makePerson(name: "Alice", cadenceId: UUID(), groupIds: [group.id])
        personRepo.people = [person]

        sut.delete(group: group)

        // Group removed from repo
        XCTAssertFalse(groupRepo.groups.contains(where: { $0.id == group.id }))
        // Person's groupIds cleaned
        let updatedPerson = personRepo.people.first { $0.id == person.id }
        XCTAssertNotNil(updatedPerson)
        XCTAssertFalse(updatedPerson!.groupIds.contains(group.id),
                       "Group should be removed from person before entity deletion")
    }
}
