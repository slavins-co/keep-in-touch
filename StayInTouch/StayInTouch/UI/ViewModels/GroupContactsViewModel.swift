//
//  GroupContactsViewModel.swift
//  KeepInTouch
//
//  Created by Codex on 2/3/26.
//

import Combine
import Foundation

@MainActor
final class GroupContactsViewModel: ObservableObject, ViewModelErrorHandling {
    @Published private(set) var people: [Person] = []
    @Published private(set) var available: [Person] = []

    private let group: Group
    private let personRepository: PersonRepository
    private var allPeople: [Person] = []

    init(group: Group, personRepository: PersonRepository = AppDependencies.shared.personRepository) {
        self.group = group
        self.personRepository = personRepository
        load()
    }

    convenience init(group: Group, dependencies: AppDependencies) {
        self.init(group: group, personRepository: dependencies.personRepository)
    }

    func load() {
        allPeople = personRepository.fetchTracked(includePaused: true)
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        people = allPeople.filter { $0.groupIds.contains(group.id) }
        available = allPeople.filter { !$0.groupIds.contains(group.id) }
    }

    func removeGroup(from person: Person) {
        var updated = person
        updated.groupIds = updated.groupIds.filter { $0 != group.id }
        updated.modifiedAt = Date()
        handleWrite("GroupContactsViewModel.removeGroup", fallback: .saveFailed("GroupContacts")) {
            try personRepository.save(updated)
        }
        NotificationCenter.default.post(name: .personDidChange, object: updated.id)
        load()
    }

    func addGroup(to personIds: [UUID]) {
        for person in allPeople where personIds.contains(person.id) {
            var updated = person
            if !updated.groupIds.contains(group.id) {
                updated.groupIds.append(group.id)
            }
            updated.modifiedAt = Date()
            handleWrite("GroupContactsViewModel.addGroup", fallback: .saveFailed("GroupContacts")) {
                try personRepository.save(updated)
            }
            NotificationCenter.default.post(name: .personDidChange, object: updated.id)
        }
        load()
    }
}
