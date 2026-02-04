//
//  CoreDataTestStack.swift
//  StayInTouchTests
//
//  Created by Codex on 2/2/26.
//

import CoreData
import XCTest
@testable import StayInTouch

final class CoreDataTestStack {
    let container: NSPersistentContainer

    init() {
        let bundle = Bundle(for: CoreDataStack.self)
        let modelURL = bundle.url(forResource: "StayInTouch", withExtension: "momd")
        let model = modelURL.flatMap { NSManagedObjectModel(contentsOf: $0) }

        container = NSPersistentContainer(
            name: "StayInTouch",
            managedObjectModel: model ?? NSManagedObjectModel()
        )

        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]

        let loadExpectation = XCTestExpectation(description: "Load in-memory store")
        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
            loadExpectation.fulfill()
        }
        _ = XCTWaiter.wait(for: [loadExpectation], timeout: 2.0)
    }
}
