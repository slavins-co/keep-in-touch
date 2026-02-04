//
//  TagEntity+Mapping.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import CoreData

extension TagEntity {
    func toDomain() -> Tag {
        Tag(
            id: id ?? UUID(),
            name: name ?? "",
            colorHex: colorHex ?? "",
            sortOrder: Int(sortOrder),
            createdAt: createdAt ?? Date(),
            modifiedAt: modifiedAt ?? Date()
        )
    }

    func apply(_ tag: Tag) {
        id = tag.id
        name = tag.name
        colorHex = tag.colorHex
        sortOrder = Int64(tag.sortOrder)
        createdAt = tag.createdAt
        modifiedAt = tag.modifiedAt
    }
}
