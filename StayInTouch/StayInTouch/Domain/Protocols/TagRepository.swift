//
//  TagRepository.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

protocol TagRepository {
    func fetch(id: UUID) -> Tag?
    func fetchAll() -> [Tag]
    func save(_ tag: Tag) throws
    func batchSave(_ tags: [Tag]) throws
    func delete(id: UUID) throws
}
