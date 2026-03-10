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
            method: TouchMethod(rawValue: method ?? TouchMethod.other.rawValue) ?? .other,
            notes: notes,
            timeOfDay: timeOfDay.flatMap(TimeOfDay.init(rawValue:)),
            createdAt: requiredField(createdAt, entity: "TouchEventEntity", field: "createdAt", fallback: Date()),
            modifiedAt: requiredField(modifiedAt, entity: "TouchEventEntity", field: "modifiedAt", fallback: Date())
        )
    }

    /// Returns `value` if non-nil; otherwise logs a data-corruption warning and returns the fallback.
    private func requiredField<T>(_ value: T?, entity: String, field: String, fallback: @autoclosure () -> T) -> T {
        guard let value else {
            AppLogger.logWarning("\(entity) has nil required field '\(field)' — possible data corruption", category: AppLogger.coreData)
            return fallback()
        }
        return value
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
