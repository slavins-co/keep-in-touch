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

    private var defaultGroup: Group!
    private var customGroup: Group!

    override func setUp() {
        super.setUp()
        groupRepo = MockGroupRepository()
        personRepo = MockPersonRepository()

        defaultGroup = TestFactory.makeGroup(id: UUID(), name: "Weekly", isDefault: true)
        customGroup = TestFactory.makeGroup(id: UUID(), name: "Monthly", frequencyDays: 30, isDefault: false)

        groupRepo.groups = [defaultGroup, customGroup]

        sut = ManageGroupsViewModel(
            groupRepository: groupRepo,
            personRepository: personRepo
        )
    }

    // MARK: - Cascade Delete: Group → People Reassignment

    func testDeleteGroupReassignsPeopleToDefaultGroup() {
        let person1 = TestFactory.makePerson(name: "Alice", groupId: customGroup.id)
        let person2 = TestFactory.makePerson(name: "Bob", groupId: customGroup.id)
        personRepo.people = [person1, person2]

        sut.delete(group: customGroup)

        let savedPeople = personRepo.savedPersons
        let reassigned = savedPeople.filter { $0.groupId == defaultGroup.id }
        XCTAssertEqual(reassigned.count, 2, "Both people should be reassigned to the default group")
    }

    func testDeleteGroupCallsRepositoryDelete() {
        sut.delete(group: customGroup)

        XCTAssertFalse(groupRepo.groups.contains(where: { $0.id == customGroup.id }),
                       "Group should be removed from repository")
    }

    func testDeleteGroupUsesBatchSave() {
        let person1 = TestFactory.makePerson(name: "Alice", groupId: customGroup.id)
        let person2 = TestFactory.makePerson(name: "Bob", groupId: customGroup.id)
        personRepo.people = [person1, person2]

        sut.delete(group: customGroup)

        XCTAssertEqual(personRepo.batchSaveCallCount, 1,
                       "Should use single batchSave instead of individual saves")
        let reassigned = personRepo.savedPersons.filter { $0.groupId == defaultGroup.id }
        XCTAssertEqual(reassigned.count, 2,
                       "Both people should be reassigned via batch save")
    }

    func testDeleteGroupWithNoPeopleJustDeletes() {
        personRepo.people = []

        sut.delete(group: customGroup)

        XCTAssertTrue(personRepo.savedPersons.isEmpty, "No people should be saved when none exist in the group")
        XCTAssertFalse(groupRepo.groups.contains(where: { $0.id == customGroup.id }),
                       "Group should still be deleted")
    }
}
