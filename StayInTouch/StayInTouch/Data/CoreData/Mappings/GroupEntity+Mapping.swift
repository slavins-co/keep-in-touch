//
//  GroupEntity+Mapping.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import CoreData

extension GroupEntity {
    func toDomain() -> Group {
        Group(
            id: requiredField(id, entity: "GroupEntity", field: "id", fallback: UUID()),
            name: requiredField(name, entity: "GroupEntity", field: "name", fallback: ""),
            frequencyDays: Int(frequencyDays),
            warningDays: Int(warningDays),
            colorHex: colorHex,
            isDefault: isDefault,
            sortOrder: Int(sortOrder),
            createdAt: requiredField(createdAt, entity: "GroupEntity", field: "createdAt", fallback: Date()),
            modifiedAt: requiredField(modifiedAt, entity: "GroupEntity", field: "modifiedAt", fallback: Date())
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

    func apply(_ group: Group) {
        id = group.id
        name = group.name
        frequencyDays = Int64(group.frequencyDays)
        warningDays = Int64(group.warningDays)
        colorHex = group.colorHex
        isDefault = group.isDefault
        sortOrder = Int64(group.sortOrder)
        createdAt = group.createdAt
        modifiedAt = group.modifiedAt
    }
}
