//
//  GroupContactsViewModel.swift
//  KeepInTouch
//
//  Created by Codex on 3/3/26.
//

import Foundation

@MainActor
final class GroupContactsViewModel: ObservableObject {
    @Published private(set) var people: [Person] = []
    @Published private(set) var available: [Person] = []

    let group: Group

    private let personRepository: PersonRepository
    private let groupRepository: GroupRepository
    private var allPeople: [Person] = []

    init(
        group: Group,
        personRepository: PersonRepository = CoreDataPersonRepository(context: CoreDataStack.shared.viewContext),
        groupRepository: GroupRepository = CoreDataGroupRepository(context: CoreDataStack.shared.viewContext)
    ) {
        self.group = group
        self.personRepository = personRepository
        self.groupRepository = groupRepository
        load()
    }

    func load() {
        allPeople = personRepository.fetchTracked(includePaused: true)
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        people = allPeople.filter { $0.groupId == group.id }
        available = allPeople.filter { $0.groupId != group.id }
    }

    func removePerson(_ person: Person) {
        guard let defaultGroup = groupRepository.fetchDefaultGroups().first else {
            AppLogger.logWarning("[GroupContactsViewModel.removePerson] No default group found", category: AppLogger.viewModel)
            ErrorToastManager.shared.show(.saveFailed("GroupContacts"))
            return
        }
        guard defaultGroup.id != group.id else { return }

        let updated = AssignGroupUseCase().assign(person: person, to: defaultGroup.id)
        do {
            try personRepository.save(updated)
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "GroupContactsViewModel.removePerson")
            ErrorToastManager.shared.show(.saveFailed("GroupContacts"))
        }
        NotificationCenter.default.post(name: .personDidChange, object: updated.id)
        load()
    }

    func addPeople(_ personIds: [UUID]) {
        let useCase = AssignGroupUseCase()
        for person in allPeople where personIds.contains(person.id) {
            let updated = useCase.assign(person: person, to: group.id)
            do {
                try personRepository.save(updated)
            } catch {
                AppLogger.logError(error, category: AppLogger.viewModel, context: "GroupContactsViewModel.addPeople")
                ErrorToastManager.shared.show(.saveFailed("GroupContacts"))
            }
            NotificationCenter.default.post(name: .personDidChange, object: updated.id)
        }
        load()
    }
}
