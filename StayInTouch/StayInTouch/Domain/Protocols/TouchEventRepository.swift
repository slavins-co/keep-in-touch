//
//  TouchEventRepository.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

protocol TouchEventRepository: Sendable {
    func fetch(id: UUID) -> TouchEvent?
    func fetchAll(for personId: UUID) -> [TouchEvent]
    func fetchAll(since: Date?) -> [TouchEvent]
    func fetchMostRecent(for personId: UUID) -> TouchEvent?
    func save(_ touchEvent: TouchEvent) throws
    func batchSave(_ touchEvents: [TouchEvent]) throws
    func delete(id: UUID) throws
    /// Deletes all events whose `id` is in the supplied list inside a single
    /// `context.save()` and triggers exactly one widget refresh. A missing id
    /// is a no-op (matches the singular `delete(id:)` contract). Empty input
    /// is a no-op — no save, no refresh.
    func batchDelete(ids: [UUID]) throws
}
