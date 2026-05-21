//
//  GroupEntity+Mapping.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import CoreData

extension TagEntity {
    func toDomain() -> Group {
        Group(
            id: requiredField(id, entity: "TagEntity", field: "id", fallback: UUID()),
            name: requiredField(name, entity: "TagEntity", field: "name", fallback: ""),
            colorHex: requiredField(colorHex, entity: "TagEntity", field: "colorHex", fallback: ""),
            sortOrder: Int(sortOrder),
            createdAt: requiredField(createdAt, entity: "TagEntity", field: "createdAt", fallback: Date()),
            modifiedAt: requiredField(modifiedAt, entity: "TagEntity", field: "modifiedAt", fallback: Date())
        )
    }

    func apply(_ group: Group) {
        id = group.id
        name = group.name
        colorHex = group.colorHex
        sortOrder = Int64(group.sortOrder)
        createdAt = group.createdAt
        modifiedAt = group.modifiedAt
    }
}
