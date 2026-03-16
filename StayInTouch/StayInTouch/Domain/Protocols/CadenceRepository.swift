//
//  CadenceRepository.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

protocol CadenceRepository {
    func fetch(id: UUID) -> Cadence?
    func fetchAll() -> [Cadence]
    func fetchDefaultGroups() -> [Cadence]
    func save(_ group: Cadence) throws
    func batchSave(_ groups: [Cadence]) throws
    func delete(id: UUID) throws
}
