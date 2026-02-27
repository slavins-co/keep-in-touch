//
//  PersonRepository.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

protocol PersonRepository {
    func fetch(id: UUID) -> Person?
    func fetchAll() -> [Person]
    func fetchTracked(includePaused: Bool) -> [Person]
    func fetchByGroup(id: UUID, includePaused: Bool) -> [Person]
    func fetchByTag(id: UUID, includePaused: Bool) -> [Person]
    func searchByName(_ query: String, includePaused: Bool) -> [Person]
    func fetchOverdue(referenceDate: Date) -> [Person]
    func save(_ person: Person) throws
    func batchSave(_ persons: [Person]) throws
    func delete(id: UUID) throws
}
