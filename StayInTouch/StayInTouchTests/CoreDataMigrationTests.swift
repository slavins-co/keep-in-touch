//
//  CoreDataMigrationTests.swift
//  KeepInTouchTests
//
//  Created by Claude on 2/24/26.
//

import CoreData
import XCTest
@testable import StayInTouch

final class CoreDataMigrationTests: XCTestCase {

    func testCoreDataStackLoadsSuccessfully() {
        let stack = CoreDataStack.make(inMemory: true, shouldSeedDefaults: false)
        XCTAssertTrue(stack.isLoaded)
        XCTAssertNil(stack.loadError)
        XCTAssertFalse(stack.migrationFailed)
    }

    func testMigrationFailedFlagDefaultsToFalse() {
        let stack = CoreDataStack.make(inMemory: true, shouldSeedDefaults: false)
        XCTAssertFalse(stack.migrationFailed)
    }

    func testModelVersionExists() {
        let bundle = Bundle(for: CoreDataStack.self)
        let modelURL = bundle.url(forResource: "StayInTouch", withExtension: "momd")
        XCTAssertNotNil(modelURL, "CoreData model bundle should exist")

        let model = NSManagedObjectModel(contentsOf: modelURL!)
        XCTAssertNotNil(model, "Should be able to load the managed object model")

        let entityNames = model!.entities.map(\.name)
        XCTAssertTrue(entityNames.contains("Person"))
        XCTAssertTrue(entityNames.contains("Group"))
        XCTAssertTrue(entityNames.contains("Tag"))
        XCTAssertTrue(entityNames.contains("TouchEvent"))
        XCTAssertTrue(entityNames.contains("AppSettings"))
    }

    func testInMemoryStoreCanInsertAndFetch() throws {
        let stack = CoreDataStack.make(inMemory: true, shouldSeedDefaults: false)
        let context = stack.viewContext

        let groupEntity = NSEntityDescription.insertNewObject(forEntityName: "Group", into: context)
        groupEntity.setValue(UUID(), forKey: "id")
        groupEntity.setValue("Test Group", forKey: "name")
        groupEntity.setValue(Int64(7), forKey: "frequencyDays")
        groupEntity.setValue(Int64(2), forKey: "warningDays")
        groupEntity.setValue(false, forKey: "isDefault")
        groupEntity.setValue(Int64(0), forKey: "sortOrder")
        groupEntity.setValue(Date(), forKey: "createdAt")
        groupEntity.setValue(Date(), forKey: "modifiedAt")

        try context.save()

        let request = NSFetchRequest<NSManagedObject>(entityName: "Group")
        let results = try context.fetch(request)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.value(forKey: "name") as? String, "Test Group")
    }

    func testResetStoreClearsFlags() {
        let stack = CoreDataStack.make(inMemory: true, shouldSeedDefaults: false)
        stack.resetStore()
        XCTAssertFalse(stack.migrationFailed)
    }
}
