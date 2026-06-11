//
//  GroupRepository.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

protocol GroupRepository: Sendable {
    func fetch(id: UUID) -> Group?
    func fetchAll() -> [Group]
    func save(_ group: Group) throws
    func batchSave(_ groups: [Group]) throws
    func delete(id: UUID) throws

    /// Returns the total number of groups without faulting any rows into
    /// memory. Backed by Core Data's `count(for:)` (audit E9, #317).
    func count() -> Int
}
