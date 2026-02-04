//
//  PersonEntityMappingTests.swift
//  StayInTouchTests
//
//  Created by Codex on 2/2/26.
//

import CoreData
import XCTest
@testable import StayInTouch

final class PersonEntityMappingTests: XCTestCase {
    func testDecodeTagIdsAcceptsMixedTypes() {
        let context = CoreDataTestStack().container.viewContext
        let entity = PersonEntity(context: context)
        let uuid = UUID()
        entity.tagIds = [uuid, uuid.uuidString] as NSArray

        let domain = entity.toDomain()
        XCTAssertEqual(domain.tagIds.count, 2)
        XCTAssertTrue(domain.tagIds.contains(uuid))
        XCTAssertTrue(domain.tagIds.contains(UUID(uuidString: uuid.uuidString)!))
    }
}
