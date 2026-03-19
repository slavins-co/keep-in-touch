//
//  CoreDataCadenceRepositoryTests.swift
//  KeepInTouchTests
//
//  Created by Claude on 3/6/26.
//

import CoreData
import XCTest
@testable import StayInTouch

final class CoreDataCadenceRepositoryTests: XCTestCase {
    private var context: NSManagedObjectContext!
    private var repo: CoreDataCadenceRepository!

    override func setUp() {
        super.setUp()
        let stack = CoreDataTestStack()
        context = stack.container.viewContext
        repo = CoreDataCadenceRepository(context: context)
    }

    // MARK: - Fetch

    func testFetchNonExistentIdReturnsNil() {
        XCTAssertNil(repo.fetch(id: UUID()))
    }

    func testFetchAllOnEmptyStoreReturnsEmpty() {
        XCTAssertTrue(repo.fetchAll().isEmpty)
    }

    func testFetchAllReturnsSortedBySortOrder() throws {
        var cadenceB = TestFactory.makeCadence(name: "Beta", isDefault: false)
        cadenceB = Cadence(id: cadenceB.id, name: cadenceB.name, frequencyDays: cadenceB.frequencyDays,
                       warningDays: cadenceB.warningDays, colorHex: cadenceB.colorHex,
                       isDefault: cadenceB.isDefault, sortOrder: 2,
                       createdAt: cadenceB.createdAt, modifiedAt: cadenceB.modifiedAt)

        var cadenceA = TestFactory.makeCadence(name: "Alpha", isDefault: false)
        cadenceA = Cadence(id: cadenceA.id, name: cadenceA.name, frequencyDays: cadenceA.frequencyDays,
                       warningDays: cadenceA.warningDays, colorHex: cadenceA.colorHex,
                       isDefault: cadenceA.isDefault, sortOrder: 1,
                       createdAt: cadenceA.createdAt, modifiedAt: cadenceA.modifiedAt)

        try repo.save(cadenceB)
        try repo.save(cadenceA)

        let all = repo.fetchAll()
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(all[0].name, "Alpha")
        XCTAssertEqual(all[1].name, "Beta")
    }

    func testFetchDefaultCadencesFiltersCorrectly() throws {
        let defaultCadence = TestFactory.makeCadence(name: "Weekly", isDefault: true)
        let customCadence = TestFactory.makeCadence(name: "Custom", isDefault: false)

        try repo.save(defaultCadence)
        try repo.save(customCadence)

        let defaults = repo.fetchDefaultCadences()
        XCTAssertEqual(defaults.count, 1)
        XCTAssertEqual(defaults.first?.name, "Weekly")
    }

    // MARK: - Save / Upsert

    func testSaveUpdatesExistingCadence() throws {
        let cadence = TestFactory.makeCadence(name: "Weekly")
        try repo.save(cadence)

        let updated = Cadence(id: cadence.id, name: "Biweekly", frequencyDays: 14,
                            warningDays: cadence.warningDays, colorHex: cadence.colorHex,
                            isDefault: cadence.isDefault, sortOrder: cadence.sortOrder,
                            createdAt: cadence.createdAt, modifiedAt: Date())
        try repo.save(updated)

        let all = repo.fetchAll()
        XCTAssertEqual(all.count, 1, "Should upsert, not duplicate")
        XCTAssertEqual(all.first?.name, "Biweekly")
        XCTAssertEqual(all.first?.frequencyDays, 14)
    }

    func testBatchSaveMultipleCadences() throws {
        let cadences = [
            TestFactory.makeCadence(name: "Daily", frequencyDays: 1),
            TestFactory.makeCadence(name: "Weekly", frequencyDays: 7),
            TestFactory.makeCadence(name: "Monthly", frequencyDays: 30)
        ]

        try repo.batchSave(cadences)

        XCTAssertEqual(repo.fetchAll().count, 3)
    }

    // MARK: - Delete

    func testDeleteNonExistentIdDoesNotThrow() {
        XCTAssertNoThrow(try repo.delete(id: UUID()))
    }
}
