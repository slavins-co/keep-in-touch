//
//  CoreDataGroupRepositoryTests.swift
//  KeepInTouchTests
//
//  Created by Claude on 3/6/26.
//

import CoreData
import XCTest
@testable import StayInTouch

final class CoreDataGroupRepositoryTests: XCTestCase {
    private var context: NSManagedObjectContext!
    private var repo: CoreDataGroupRepository!

    override func setUp() {
        super.setUp()
        let stack = CoreDataTestStack()
        context = stack.container.viewContext
        repo = CoreDataGroupRepository(context: context)
    }

    // MARK: - Fetch

    func testFetchNonExistentIdReturnsNil() {
        XCTAssertNil(repo.fetch(id: UUID()))
    }

    func testFetchAllOnEmptyStoreReturnsEmpty() {
        XCTAssertTrue(repo.fetchAll().isEmpty)
    }

    func testFetchAllReturnsSortedBySortOrder() throws {
        var groupB = TestFactory.makeGroup(name: "Beta", isDefault: false)
        groupB = Group(id: groupB.id, name: groupB.name, frequencyDays: groupB.frequencyDays,
                       warningDays: groupB.warningDays, colorHex: groupB.colorHex,
                       isDefault: groupB.isDefault, sortOrder: 2,
                       createdAt: groupB.createdAt, modifiedAt: groupB.modifiedAt)

        var groupA = TestFactory.makeGroup(name: "Alpha", isDefault: false)
        groupA = Group(id: groupA.id, name: groupA.name, frequencyDays: groupA.frequencyDays,
                       warningDays: groupA.warningDays, colorHex: groupA.colorHex,
                       isDefault: groupA.isDefault, sortOrder: 1,
                       createdAt: groupA.createdAt, modifiedAt: groupA.modifiedAt)

        try repo.save(groupB)
        try repo.save(groupA)

        let all = repo.fetchAll()
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(all[0].name, "Alpha")
        XCTAssertEqual(all[1].name, "Beta")
    }

    func testFetchDefaultGroupsFiltersCorrectly() throws {
        let defaultGroup = TestFactory.makeGroup(name: "Weekly", isDefault: true)
        let customGroup = TestFactory.makeGroup(name: "Custom", isDefault: false)

        try repo.save(defaultGroup)
        try repo.save(customGroup)

        let defaults = repo.fetchDefaultGroups()
        XCTAssertEqual(defaults.count, 1)
        XCTAssertEqual(defaults.first?.name, "Weekly")
    }

    // MARK: - Save / Upsert

    func testSaveUpdatesExistingGroup() throws {
        let group = TestFactory.makeGroup(name: "Weekly")
        try repo.save(group)

        let updated = Group(id: group.id, name: "Biweekly", frequencyDays: 14,
                            warningDays: group.warningDays, colorHex: group.colorHex,
                            isDefault: group.isDefault, sortOrder: group.sortOrder,
                            createdAt: group.createdAt, modifiedAt: Date())
        try repo.save(updated)

        let all = repo.fetchAll()
        XCTAssertEqual(all.count, 1, "Should upsert, not duplicate")
        XCTAssertEqual(all.first?.name, "Biweekly")
        XCTAssertEqual(all.first?.frequencyDays, 14)
    }

    func testBatchSaveMultipleGroups() throws {
        let groups = [
            TestFactory.makeGroup(name: "Daily", frequencyDays: 1),
            TestFactory.makeGroup(name: "Weekly", frequencyDays: 7),
            TestFactory.makeGroup(name: "Monthly", frequencyDays: 30)
        ]

        try repo.batchSave(groups)

        XCTAssertEqual(repo.fetchAll().count, 3)
    }

    // MARK: - Delete

    func testDeleteNonExistentIdDoesNotThrow() {
        XCTAssertNoThrow(try repo.delete(id: UUID()))
    }
}
