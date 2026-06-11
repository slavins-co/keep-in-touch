//
//  CadenceContactsViewModel.swift
//  KeepInTouch
//
//  Created by Codex on 3/3/26.
//

import Combine
import Foundation

@MainActor
final class CadenceContactsViewModel: ObservableObject, ViewModelErrorHandling {
    @Published private(set) var people: [Person] = []
    @Published private(set) var available: [Person] = []
    @Published private(set) var otherCadences: [Cadence] = []

    let cadence: Cadence

    private let personRepository: PersonRepository
    private let cadenceRepository: CadenceRepository
    private var allPeople: [Person] = []

    init(
        cadence: Cadence,
        personRepository: PersonRepository = AppDependencies.shared.personRepository,
        cadenceRepository: CadenceRepository = AppDependencies.shared.cadenceRepository
    ) {
        self.cadence = cadence
        self.personRepository = personRepository
        self.cadenceRepository = cadenceRepository
        load()
    }

    convenience init(cadence: Cadence, dependencies: AppDependencies) {
        self.init(
            cadence: cadence,
            personRepository: dependencies.personRepository,
            cadenceRepository: dependencies.cadenceRepository
        )
    }

    func load() {
        allPeople = personRepository.fetchTracked(includePaused: true)
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        people = allPeople.filter { $0.cadenceId == cadence.id }
        available = allPeople.filter { $0.cadenceId != cadence.id }
        otherCadences = cadenceRepository.fetchAll()
            .filter { $0.id != cadence.id }
            .sorted { lhs, rhs in
                if lhs.isDefault != rhs.isDefault { return lhs.isDefault }
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    func movePerson(_ person: Person, to destinationCadenceId: UUID) {
        let updated = AssignCadenceUseCase().assign(person: person, to: destinationCadenceId)
        handleWrite("CadenceContactsViewModel.movePerson", fallback: .saveFailed("CadenceContacts")) {
            try personRepository.save(updated)
        }
        NotificationCenter.default.post(name: .personDidChange, object: updated.id)
        load()
    }

    func addPeople(_ personIds: [UUID]) {
        let useCase = AssignCadenceUseCase()
        // E12: batch the writes into one save + one .personDidChange post.
        // Prior loop did N saves and posted N notifications — every observer
        // (HomeView, ContactsListView, SettingsView, StatsView,
        // NotificationScheduler debouncer) ran N times. All five are "reload
        // my data" handlers with no per-person dependency, so collapsing to
        // a single post is safe and strictly fewer reloads. The scheduler's
        // 1s debouncer would have coalesced anyway; this also covers the
        // SwiftUI observers that bypass it.
        let updates = allPeople
            .filter { personIds.contains($0.id) }
            .map { useCase.assign(person: $0, to: cadence.id) }
        guard !updates.isEmpty else {
            load()
            return
        }
        handleWrite("CadenceContactsViewModel.addPeople", fallback: .saveFailed("CadenceContacts")) {
            try personRepository.batchSave(updates)
        }
        // Pass nil as object since the post covers a set of people; observers
        // ignore the object payload (they reload everything anyway).
        NotificationCenter.default.post(name: .personDidChange, object: nil)
        load()
    }
}
