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
        people = personRepository.fetchByGroup(id: group.id, includePaused: true)
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

        let allTracked = personRepository.fetchTracked(includePaused: true)
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        available = allTracked.filter { $0.groupId != group.id }
    }

    func removePerson(_ person: Person) {
        guard let defaultGroup = groupRepository.fetchDefaultGroups().first,
              defaultGroup.id != group.id else { return }

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
        let allTracked = personRepository.fetchTracked(includePaused: true)
        for person in allTracked where personIds.contains(person.id) {
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
