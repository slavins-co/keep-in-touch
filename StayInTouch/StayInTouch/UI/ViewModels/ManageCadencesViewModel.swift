//
//  ManageCadencesViewModel.swift
//  KeepInTouch
//
//  Created by Codex on 2/3/26.
//

import Foundation

@MainActor
final class ManageCadencesViewModel: ObservableObject {
    @Published private(set) var cadences: [Cadence] = []
    @Published private(set) var countsByCadence: [UUID: Int] = [:]

    private let cadenceRepository: CadenceRepository
    private let personRepository: PersonRepository

    init(
        cadenceRepository: CadenceRepository = CoreDataCadenceRepository(context: CoreDataStack.shared.viewContext),
        personRepository: PersonRepository = CoreDataPersonRepository(context: CoreDataStack.shared.viewContext)
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
                do {
                    try cadenceRepository.save(cleared)
                } catch let error as RepositoryError {
                    AppLogger.logError(error, category: AppLogger.viewModel, context: "ManageCadencesViewModel.save.clearDefault")
                    ErrorToastManager.shared.show(AppError(message: error.userMessage))
                } catch {
                    AppLogger.logError(error, category: AppLogger.viewModel, context: "ManageCadencesViewModel.save.clearDefault (unexpected)")
                    ErrorToastManager.shared.show(.saveFailed("ManageCadences"))
                }
            }
            updated.isDefault = true
        }

        do {
            try cadenceRepository.save(updated)
        } catch let error as RepositoryError {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "ManageCadencesViewModel.save")
            ErrorToastManager.shared.show(AppError(message: error.userMessage))
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "ManageCadencesViewModel.save (unexpected)")
            ErrorToastManager.shared.show(.saveFailed("ManageCadences"))
        }
        load()
    }

    func delete(cadence: Cadence) {
        // Enforce: reassign any remaining people to default cadence before deleting
        if let fallback = cadences.first(where: { $0.isDefault && $0.id != cadence.id })
            ?? cadences.first(where: { $0.id != cadence.id }) {
            movePeople(from: cadence, to: fallback)
        }
        do {
            try cadenceRepository.delete(id: cadence.id)
        } catch let error as RepositoryError {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "ManageCadencesViewModel.delete")
            ErrorToastManager.shared.show(AppError(message: error.userMessage))
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "ManageCadencesViewModel.delete (unexpected)")
            ErrorToastManager.shared.show(.deleteFailed("ManageCadences"))
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
        do {
            try personRepository.batchSave(updatedPeople)
        } catch let error as RepositoryError {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "ManageCadencesViewModel.movePeople")
            ErrorToastManager.shared.show(AppError(message: error.userMessage))
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "ManageCadencesViewModel.movePeople (unexpected)")
            ErrorToastManager.shared.show(.saveFailed("ManageCadences"))
        }
    }

    func defaultCadence() -> Cadence? {
        cadences.first(where: { $0.isDefault })
    }
}
