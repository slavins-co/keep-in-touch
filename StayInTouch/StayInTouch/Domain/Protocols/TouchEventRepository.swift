//
//  TouchEventRepository.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

protocol TouchEventRepository {
    func fetch(id: UUID) -> TouchEvent?
    func fetchAll(for personId: UUID) -> [TouchEvent]
    func fetchMostRecent(for personId: UUID) -> TouchEvent?
    func save(_ touchEvent: TouchEvent) throws
    func batchSave(_ touchEvents: [TouchEvent]) throws
    func delete(id: UUID) throws
}
