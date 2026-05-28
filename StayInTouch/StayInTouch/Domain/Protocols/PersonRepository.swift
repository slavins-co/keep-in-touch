//
//  PersonRepository.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

protocol PersonRepository {
    func fetch(id: UUID) -> Person?
    func fetchAll() -> [Person]
    func fetchTracked(includePaused: Bool) -> [Person]
    func fetchByCadence(id: UUID, includePaused: Bool) -> [Person]
    func fetchByGroup(id: UUID, includePaused: Bool) -> [Person]
    func searchByName(_ query: String, includePaused: Bool) -> [Person]
    func fetchOverdue(referenceDate: Date) -> [Person]
    func save(_ person: Person) throws
    func batchSave(_ persons: [Person]) throws
    func delete(id: UUID) throws

    /// Returns the number of currently-paused tracked people without
    /// faulting the matching rows into memory. Backed by Core Data's
    /// `count(for:)` (audit E9, #317) — orders of magnitude cheaper than
    /// fetching every tracked person and filtering in Swift just to read
    /// a display count.
    func pausedCount() -> Int

    /// Returns the number of tracked people whose snooze is still active
    /// (`snoozedUntil > referenceDate`). Takes a reference date because
    /// "active vs expired" depends on now, unlike `pausedCount()`. Backed
    /// by `count(for:)` — no row materialization.
    func snoozedCount(referenceDate: Date) -> Int
}
