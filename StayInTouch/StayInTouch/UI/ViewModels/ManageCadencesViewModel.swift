//
//  ManageCadencesViewModel.swift
//  KeepInTouch
//
//  Created by Codex on 2/3/26.
//

import Combine
import Foundation

@MainActor
final class ManageCadencesViewModel: ObservableObject, ViewModelErrorHandling {
    @Published private(set) var cadences: [Cadence] = []
    @Published private(set) var countsByCadence: [UUID: Int] = [:]

    private let cadenceRepository: CadenceRepository
    private let personRepository: PersonRepository

    init(
        cadenceRepository: CadenceRepository = AppDependencies.shared.cadenceRepository,
        personRepository: PersonRepository = AppDependencies.shared.personRepository
    ) {
        self.cadenceRepository = cadenceRepository
        self.personRepository = personRepository
        load()
    }

    convenience init(dependencies: AppDependencies) {
        self.init(
            cadenceRepository: dependencies.cadenceRepository,
            personRepository: dependencies.personRepository
        )
    }

    func load() {
        cadences = cadenceRepository.fetchAll().sorted { lhs, rhs in
            if lhs.isDefault != rhs.isDefault { return lhs.isDefault }
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        let people = personRepository.fetchTracked(includePaused: true)
        var counts: [UUID: Int] = [:]
        for person in people {
            let cadenceId = person.cadenceId
            counts[cadenceId, default: 0] += 1
        }
        countsByCadence = counts
    }

    func save(_ cadence: Cadence, makeDefault: Bool) {
        var updated = cadence
        updated.modifiedAt = Date()

        if makeDefault {
            let all = cadenceRepository.fetchAll()
            for existing in all where existing.id != updated.id && existing.isDefault {
                var cleared = existing
                cleared.isDefault = false
                cleared.modifiedAt = Date()
                handleRepositoryWrite("ManageCadencesViewModel.save.clearDefault", fallback: .saveFailed("ManageCadences")) {
                    try cadenceRepository.save(cleared)
                }
            }
            updated.isDefault = true
        }

        handleRepositoryWrite("ManageCadencesViewModel.save", fallback: .saveFailed("ManageCadences")) {
            try cadenceRepository.save(updated)
        }
        load()
    }

    func delete(cadence: Cadence) {
        // Enforce: reassign any remaining people to default cadence before deleting
        if let fallback = cadences.first(where: { $0.isDefault && $0.id != cadence.id })
            ?? cadences.first(where: { $0.id != cadence.id }) {
            movePeople(from: cadence, to: fallback)
        }
        handleRepositoryWrite("ManageCadencesViewModel.delete", fallback: .deleteFailed("ManageCadences")) {
            try cadenceRepository.delete(id: cadence.id)
        }
        load()
    }

    func movePeople(from cadence: Cadence, to defaultCadence: Cadence) {
        let people = personRepository.fetchByCadence(id: cadence.id, includePaused: true)
        guard !people.isEmpty else { return }
        let now = Date()
        let updatedPeople = people.map { person -> Person in
            var updated = person
            updated.cadenceId = defaultCadence.id
            updated.cadenceAddedAt = now
            updated.modifiedAt = now
            return updated
        }
        handleRepositoryWrite("ManageCadencesViewModel.movePeople", fallback: .saveFailed("ManageCadences")) {
            try personRepository.batchSave(updatedPeople)
        }
    }

    func defaultCadence() -> Cadence? {
        cadences.first(where: { $0.isDefault })
    }
}
