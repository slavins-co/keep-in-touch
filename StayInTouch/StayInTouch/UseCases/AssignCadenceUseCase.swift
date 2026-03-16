//
//  AssignCadenceUseCase.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

struct AssignCadenceUseCase {
    let referenceDate: Date

    init(referenceDate: Date = Date()) {
        self.referenceDate = referenceDate
    }

    func assign(person: Person, to cadenceId: UUID) -> Person {
        if person.cadenceId == cadenceId {
            guard person.cadenceAddedAt == nil else { return person }
            var updated = person
            updated.cadenceAddedAt = referenceDate
            updated.modifiedAt = referenceDate
            return updated
        }

        var updated = person
        updated.cadenceId = cadenceId
        updated.cadenceAddedAt = referenceDate
        updated.modifiedAt = referenceDate
        return updated
    }
}
