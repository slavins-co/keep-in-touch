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
    func fetchDefaultCadences() -> [Cadence]
    func save(_ cadence: Cadence) throws
    func batchSave(_ cadences: [Cadence]) throws
    func delete(id: UUID) throws
}
