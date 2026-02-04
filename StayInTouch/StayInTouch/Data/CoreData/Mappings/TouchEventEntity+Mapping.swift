//
//  TouchEventEntity+Mapping.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import CoreData

extension TouchEventEntity {
    func toDomain() -> TouchEvent {
        TouchEvent(
            id: id ?? UUID(),
            personId: personId ?? UUID(),
            at: at ?? Date(),
            method: TouchMethod(rawValue: method ?? TouchMethod.other.rawValue) ?? .other,
            notes: notes,
            createdAt: createdAt ?? Date(),
            modifiedAt: modifiedAt ?? Date()
        )
    }

    func apply(_ touchEvent: TouchEvent) {
        id = touchEvent.id
        personId = touchEvent.personId
        at = touchEvent.at
        method = touchEvent.method.rawValue
        notes = touchEvent.notes
        createdAt = touchEvent.createdAt
        modifiedAt = touchEvent.modifiedAt
    }
}
