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
            id: id ?? UUID(),
            name: name ?? "",
            frequencyDays: Int(frequencyDays),
            warningDays: Int(warningDays),
            colorHex: colorHex,
            isDefault: isDefault,
            sortOrder: Int(sortOrder),
            createdAt: createdAt ?? Date(),
            modifiedAt: modifiedAt ?? Date()
        )
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
