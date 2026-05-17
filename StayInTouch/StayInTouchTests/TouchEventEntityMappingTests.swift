//
//  TouchEventEntityMappingTests.swift
//  KeepInTouchTests
//
//  Created by Codex on 5/17/26.
//

import CoreData
import XCTest
@testable import StayInTouch

final class TouchEventEntityMappingTests: XCTestCase {
    private var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        context = CoreDataTestStack().container.viewContext
    }

    // MARK: - Legacy raw-value coercion (#299)
    //
    // PR #296 added `.whatsapp` and `.signal` TouchMethod cases that were
    // removed in #299 (collapsed to medium-only). Existing TouchEvent rows
    // persisted with "WhatsApp" or "Signal" string raw values must continue
    // to load — they coerce to `.text` on read. On next save the row is
    // rewritten with the canonical raw value (rolling natural migration).

    func testLegacyWhatsAppRawValueCoercesToText() {
        let entity = makeEntity(methodRawValue: "WhatsApp")

        let domain = entity.toDomain()

        XCTAssertEqual(domain.method, .text, "Legacy WhatsApp raw value must coerce to .text")
    }

    func testLegacySignalRawValueCoercesToText() {
        let entity = makeEntity(methodRawValue: "Signal")

        let domain = entity.toDomain()

        XCTAssertEqual(domain.method, .text, "Legacy Signal raw value must coerce to .text")
    }

    // MARK: - Canonical raw values continue to map correctly

    func testTextRawValueMaps() {
        XCTAssertEqual(makeEntity(methodRawValue: "Text").toDomain().method, .text)
    }

    func testCallRawValueMaps() {
        XCTAssertEqual(makeEntity(methodRawValue: "Call").toDomain().method, .call)
    }

    func testIRLRawValueMaps() {
        XCTAssertEqual(makeEntity(methodRawValue: "IRL").toDomain().method, .irl)
    }

    func testEmailRawValueMaps() {
        XCTAssertEqual(makeEntity(methodRawValue: "Email").toDomain().method, .email)
    }

    func testFaceTimeRawValueMaps() {
        XCTAssertEqual(makeEntity(methodRawValue: "FaceTime").toDomain().method, .facetime)
    }

    func testOtherRawValueMaps() {
        XCTAssertEqual(makeEntity(methodRawValue: "Other").toDomain().method, .other)
    }

    func testUnknownRawValueFallsBackToOther() {
        XCTAssertEqual(
            makeEntity(methodRawValue: "Telegram").toDomain().method,
            .other,
            "Unknown raw values must fall back to .other rather than crashing"
        )
    }

    func testNilRawValueFallsBackToOther() {
        let entity = TouchEventEntity(context: context)
        entity.id = UUID()
        entity.personId = UUID()
        entity.at = Date()
        entity.method = nil
        entity.createdAt = Date()
        entity.modifiedAt = Date()

        XCTAssertEqual(entity.toDomain().method, .other)
    }

    // MARK: - Round-trip for canonical cases

    func testRoundTripFaceTimeMethod() {
        let entity = TouchEventEntity(context: context)
        let touchEvent = TouchEvent(
            id: UUID(),
            personId: UUID(),
            at: Date(),
            method: .facetime,
            notes: nil,
            timeOfDay: nil,
            createdAt: Date(),
            modifiedAt: Date()
        )
        entity.apply(touchEvent)

        let roundTripped = entity.toDomain()

        XCTAssertEqual(roundTripped.method, .facetime)
        XCTAssertEqual(entity.method, "FaceTime", "Canonical raw value must persist as 'FaceTime'")
    }

    // MARK: - Helpers

    private func makeEntity(methodRawValue: String) -> TouchEventEntity {
        let entity = TouchEventEntity(context: context)
        entity.id = UUID()
        entity.personId = UUID()
        entity.at = Date()
        entity.method = methodRawValue
        entity.createdAt = Date()
        entity.modifiedAt = Date()
        return entity
    }
}
