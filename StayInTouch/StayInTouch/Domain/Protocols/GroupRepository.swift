//
//  GroupRepository.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

protocol GroupRepository {
    func fetch(id: UUID) -> Group?
    func fetchAll() -> [Group]
    func fetchDefaultGroups() -> [Group]
    func save(_ group: Group) throws
    func delete(id: UUID) throws
}
