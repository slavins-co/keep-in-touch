//
//  AssignGroupUseCase.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

struct AssignGroupUseCase {
    let referenceDate: Date

    init(referenceDate: Date = Date()) {
        self.referenceDate = referenceDate
    }

    func assign(person: Person, to groupId: UUID) -> Person {
        if person.groupId == groupId {
            guard person.groupAddedAt == nil else { return person }
            var updated = person
            updated.groupAddedAt = referenceDate
            updated.modifiedAt = referenceDate
            return updated
        }

        var updated = person
        updated.groupId = groupId
        updated.groupAddedAt = referenceDate
        updated.modifiedAt = referenceDate
        return updated
    }
}
