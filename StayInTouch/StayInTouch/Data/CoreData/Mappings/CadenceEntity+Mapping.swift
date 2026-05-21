//
//  CadenceEntity+Mapping.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import CoreData

extension GroupEntity {
    func toDomain() -> Cadence {
        Cadence(
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

    func apply(_ cadence: Cadence) {
        id = cadence.id
        name = cadence.name
        frequencyDays = Int64(cadence.frequencyDays)
        warningDays = Int64(cadence.warningDays)
        colorHex = cadence.colorHex
        isDefault = cadence.isDefault
        sortOrder = Int64(cadence.sortOrder)
        createdAt = cadence.createdAt
        modifiedAt = cadence.modifiedAt
    }
}
