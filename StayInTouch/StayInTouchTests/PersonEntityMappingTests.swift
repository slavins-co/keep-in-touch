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
        XCTAssertEqual(domain.groupIds.count, 2)
        XCTAssertTrue(domain.groupIds.contains(uuid))
        XCTAssertTrue(domain.groupIds.contains(UUID(uuidString: uuid.uuidString)!))
    }

    // MARK: - Nil required field fallbacks (#214)

    func testNilIdFallsBackToNewUUID() {
        let entity = PersonEntity(context: context)
        entity.id = nil
        entity.displayName = "Alice"
        entity.groupId = UUID()

        let domain = entity.toDomain()
        XCTAssertNotNil(domain.id, "toDomain should produce a non-nil id even when entity.id is nil")
    }

    func testNilDisplayNameFallsBackToEmpty() {
        let entity = PersonEntity(context: context)
        entity.id = UUID()
        entity.displayName = nil
        entity.groupId = UUID()

        let domain = entity.toDomain()
        XCTAssertEqual(domain.displayName, "", "toDomain should fall back to empty string when displayName is nil")
    }

    // MARK: - Nickname round-trip (#275)

    func testNicknameRoundTrips() {
        let entity = PersonEntity(context: context)
        entity.id = UUID()
        entity.displayName = "Robert"
        entity.nickname = "Bobby"
        entity.initials = "RJ"
        entity.avatarColor = "#FF0000"
        entity.groupId = UUID()
        entity.isPaused = false
        entity.isTracked = true
        entity.notificationsMuted = false
        entity.contactUnavailable = false
        entity.sortOrder = 0
        entity.createdAt = Date()
        entity.modifiedAt = Date()

        let domain = entity.toDomain()
        XCTAssertEqual(domain.nickname, "Bobby")

        // Round-trip back
        let entity2 = PersonEntity(context: context)
        entity2.apply(domain)
        XCTAssertEqual(entity2.nickname, "Bobby")
    }

    func testNilNicknameRoundTrips() {
        let entity = PersonEntity(context: context)
        entity.id = UUID()
        entity.displayName = "Alice"
        entity.nickname = nil
        entity.initials = "AS"
        entity.avatarColor = "#0000FF"
        entity.groupId = UUID()
        entity.isPaused = false
        entity.isTracked = true
        entity.notificationsMuted = false
        entity.contactUnavailable = false
        entity.sortOrder = 0
        entity.createdAt = Date()
        entity.modifiedAt = Date()

        let domain = entity.toDomain()
        XCTAssertNil(domain.nickname)
    }

    func testNilGroupIdFallsBackToNewUUID() {
        let entity = PersonEntity(context: context)
        entity.id = UUID()
        entity.displayName = "Bob"
        entity.groupId = nil

        let domain = entity.toDomain()
        XCTAssertNotNil(domain.cadenceId, "toDomain should produce a non-nil cadenceId even when entity.groupId is nil")
    }
}
