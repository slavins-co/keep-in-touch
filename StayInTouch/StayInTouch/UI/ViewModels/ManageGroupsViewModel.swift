//
//  ManageGroupsViewModel.swift
//  KeepInTouch
//
//  Created by Codex on 2/3/26.
//

import Combine
import Foundation

@MainActor
final class ManageGroupsViewModel: ObservableObject, ViewModelErrorHandling {
    @Published private(set) var groups: [Group] = []
    @Published private(set) var countsByGroup: [UUID: Int] = [:]

    private let groupRepository: GroupRepository
    private let personRepository: PersonRepository

    init(
        groupRepository: GroupRepository = AppDependencies.shared.groupRepository,
        personRepository: PersonRepository = AppDependencies.shared.personRepository
    ) {
        self.groupRepository = groupRepository
        self.personRepository = personRepository
        load()
    }

    convenience init(dependencies: AppDependencies) {
        self.init(
            groupRepository: dependencies.groupRepository,
            personRepository: dependencies.personRepository
        )
    }

    func load() {
        groups = groupRepository.fetchAll().sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        let people = personRepository.fetchTracked(includePaused: true)
        var counts: [UUID: Int] = [:]
        for person in people {
            for groupId in person.groupIds {
                counts[groupId, default: 0] += 1
            }
        }
        countsByGroup = counts
    }

    func save(_ group: Group) {
        var updated = group
        updated.modifiedAt = Date()
        handleRepositoryWrite("ManageGroupsViewModel.save", fallback: .saveFailed("ManageGroups")) {
            try groupRepository.save(updated)
        }
        load()
    }

    func delete(group: Group) {
        // Remove group references from persons first, then delete entity
        // This order prevents orphaned groupId references on crash
        removeGroupFromPeople(groupId: group.id)
        handleRepositoryWrite("ManageGroupsViewModel.delete", fallback: .deleteFailed("ManageGroups")) {
            try groupRepository.delete(id: group.id)
        }
        load()
    }

    func removeGroupFromPeople(groupId: UUID) {
        let people = personRepository.fetchTracked(includePaused: true)
        let now = Date()
        var updatedPeople: [Person] = []
        for person in people where person.groupIds.contains(groupId) {
            var updated = person
            updated.groupIds = updated.groupIds.filter { $0 != groupId }
            updated.modifiedAt = now
            updatedPeople.append(updated)
        }
        guard !updatedPeople.isEmpty else { return }
        handleRepositoryWrite("ManageGroupsViewModel.removeGroupFromPeople", fallback: .saveFailed("ManageGroups")) {
            try personRepository.batchSave(updatedPeople)
        }
    }
}
