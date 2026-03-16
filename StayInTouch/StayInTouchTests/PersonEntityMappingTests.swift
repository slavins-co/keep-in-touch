//
//  PersonEntityMappingTests.swift
//  KeepInTouchTests
//
//  Created by Codex on 2/2/26.
//

import CoreData
import XCTest
@testable import StayInTouch

final class PersonEntityMappingTests: XCTestCase {
    private var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        context = CoreDataTestStack().container.viewContext
    }

    func testDecodeTagIdsAcceptsMixedTypes() {
        let entity = PersonEntity(context: context)
        let uuid = UUID()
        entity.tagIds = [uuid, uuid.uuidString] as NSArray

        let domain = entity.toDomain()
        XCTAssertEqual(domain.tagIds.count, 2)
        XCTAssertTrue(domain.tagIds.contains(uuid))
        XCTAssertTrue(domain.tagIds.contains(UUID(uuidString: uuid.uuidString)!))
    }

    // MARK: - Nil required field fallbacks (#214)

    func testNilIdFallsBackToNewUUID() {
        let entity = PersonEntity(context: context)
        entity.id = nil
        entity.displayName = "Alice"
        entity.cadenceId = UUID()

        let domain = entity.toDomain()
        XCTAssertNotNil(domain.id, "toDomain should produce a non-nil id even when entity.id is nil")
    }

    func testNilDisplayNameFallsBackToEmpty() {
        let entity = PersonEntity(context: context)
        entity.id = UUID()
        entity.displayName = nil
        entity.cadenceId = UUID()

        let domain = entity.toDomain()
        XCTAssertEqual(domain.displayName, "", "toDomain should fall back to empty string when displayName is nil")
    }

    func testNilGroupIdFallsBackToNewUUID() {
        let entity = PersonEntity(context: context)
        entity.id = UUID()
        entity.displayName = "Bob"
        entity.cadenceId = nil

        let domain = entity.toDomain()
        XCTAssertNotNil(domain.cadenceId, "toDomain should produce a non-nil cadenceId even when entity.cadenceId is nil")
    }
}
