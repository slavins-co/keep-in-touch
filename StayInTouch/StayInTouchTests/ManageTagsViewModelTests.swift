//
//  ManageTagsViewModelTests.swift
//  KeepInTouchTests
//
//  Created by Claude on 2/27/26.
//

import XCTest
@testable import StayInTouch

@MainActor
final class ManageTagsViewModelTests: XCTestCase {
    private var tagRepo: MockTagRepository!
    private var personRepo: MockPersonRepository!
    private var sut: ManageTagsViewModel!

    private var tag: Tag!

    override func setUp() {
        super.setUp()
        tagRepo = MockTagRepository()
        personRepo = MockPersonRepository()

        tag = TestFactory.makeTag(id: UUID(), name: "Work")
        tagRepo.tags = [tag]

        sut = ManageTagsViewModel(
            tagRepository: tagRepo,
            personRepository: personRepo
        )
    }

    // MARK: - Cascade Delete: Tag → People Tag Removal

    func testDeleteTagRemovesTagIdFromAllPeople() {
        let groupId = UUID()
        let person1 = TestFactory.makePerson(name: "Alice", groupId: groupId, tagIds: [tag.id])
        let person2 = TestFactory.makePerson(name: "Bob", groupId: groupId, tagIds: [tag.id, UUID()])
        personRepo.people = [person1, person2]

        sut.delete(tag: tag)

        // Both people should have been saved with the tag removed
        let savedPeople = personRepo.savedPersons
        XCTAssertEqual(savedPeople.count, 2, "Both people should be updated")
        for person in savedPeople {
            XCTAssertFalse(person.tagIds.contains(tag.id),
                           "\(person.displayName) should no longer have the deleted tag")
        }
    }

    func testDeleteTagCallsRepositoryDelete() {
        sut.delete(tag: tag)

        XCTAssertFalse(tagRepo.tags.contains(where: { $0.id == tag.id }),
                       "Tag should be removed from repository")
    }

    func testDeleteTagUsesBatchSave() {
        let groupId = UUID()
        let person1 = TestFactory.makePerson(name: "Alice", groupId: groupId, tagIds: [tag.id])
        let person2 = TestFactory.makePerson(name: "Bob", groupId: groupId, tagIds: [tag.id])
        personRepo.people = [person1, person2]

        sut.delete(tag: tag)

        XCTAssertEqual(personRepo.batchSaveCallCount, 1,
                       "Should use single batchSave instead of individual saves")
        XCTAssertEqual(personRepo.savedPersons.count, 2,
                       "Both people should still be updated")
    }

    func testDeleteTagRemovesFromPeopleBeforeDeleting() {
        // Verify order: removeTagFromPeople runs before tagRepository.delete
        // After delete, tag should be gone AND people should be cleaned
        let person = TestFactory.makePerson(name: "Alice", groupId: UUID(), tagIds: [tag.id])
        personRepo.people = [person]

        sut.delete(tag: tag)

        // Tag removed from repo
        XCTAssertFalse(tagRepo.tags.contains(where: { $0.id == tag.id }))
        // Person's tagIds cleaned
        let updatedPerson = personRepo.people.first { $0.id == person.id }
        XCTAssertNotNil(updatedPerson)
        XCTAssertFalse(updatedPerson!.tagIds.contains(tag.id),
                       "Tag should be removed from person before entity deletion")
    }
}
