//
//  TouchEventEntity+Mapping.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import CoreData

extension TouchEventEntity {
    func toDomain() -> TouchEvent {
        TouchEvent(
            id: requiredField(id, entity: "TouchEventEntity", field: "id", fallback: UUID()),
            personId: requiredField(personId, entity: "TouchEventEntity", field: "personId", fallback: UUID()),
            at: requiredField(at, entity: "TouchEventEntity", field: "at", fallback: Date()),
            method: Self.coerceMethod(method),
            notes: notes,
            timeOfDay: timeOfDay.flatMap(TimeOfDay.init(rawValue:)),
            createdAt: requiredField(createdAt, entity: "TouchEventEntity", field: "createdAt", fallback: Date()),
            modifiedAt: requiredField(modifiedAt, entity: "TouchEventEntity", field: "modifiedAt", fallback: Date())
        )
    }

    // Legacy raw values "WhatsApp" and "Signal" came from #296's TouchMethod
    // expansion. #299 collapsed TouchMethod to medium-only, so they read as
    // .text. On next save the row is rewritten with the canonical raw value.
    private static func coerceMethod(_ rawValue: String?) -> TouchMethod {
        switch rawValue {
        case "WhatsApp", "Signal":
            return .text
        case let value?:
            return TouchMethod(rawValue: value) ?? .other
        case nil:
            return .other
        }
    }

    func apply(_ touchEvent: TouchEvent) {
        id = touchEvent.id
        personId = touchEvent.personId
        at = touchEvent.at
        method = touchEvent.method.rawValue
        notes = touchEvent.notes
        timeOfDay = touchEvent.timeOfDay?.rawValue
        createdAt = touchEvent.createdAt
        modifiedAt = touchEvent.modifiedAt
    }
}
