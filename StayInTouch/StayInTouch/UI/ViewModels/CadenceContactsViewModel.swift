//
//  CadenceContactsViewModel.swift
//  KeepInTouch
//
//  Created by Codex on 3/3/26.
//

import Foundation

@MainActor
final class CadenceContactsViewModel: ObservableObject {
    @Published private(set) var people: [Person] = []
    @Published private(set) var available: [Person] = []
    @Published private(set) var otherCadences: [Cadence] = []

    let cadence: Cadence

    private let personRepository: PersonRepository
    private let cadenceRepository: CadenceRepository
    private var allPeople: [Person] = []

    init(
        cadence: Cadence,
        personRepository: PersonRepository = CoreDataPersonRepository(context: CoreDataStack.shared.viewContext),
        cadenceRepository: CadenceRepository = CoreDataCadenceRepository(context: CoreDataStack.shared.viewContext)
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
        do {
            try personRepository.save(updated)
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "CadenceContactsViewModel.movePerson")
            ErrorToastManager.shared.show(.saveFailed("CadenceContacts"))
        }
        NotificationCenter.default.post(name: .personDidChange, object: updated.id)
        load()
    }

    func addPeople(_ personIds: [UUID]) {
        let useCase = AssignCadenceUseCase()
        for person in allPeople where personIds.contains(person.id) {
            let updated = useCase.assign(person: person, to: cadence.id)
            do {
                try personRepository.save(updated)
            } catch {
                AppLogger.logError(error, category: AppLogger.viewModel, context: "CadenceContactsViewModel.addPeople")
                ErrorToastManager.shared.show(.saveFailed("CadenceContacts"))
            }
            NotificationCenter.default.post(name: .personDidChange, object: updated.id)
        }
        load()
    }
}
