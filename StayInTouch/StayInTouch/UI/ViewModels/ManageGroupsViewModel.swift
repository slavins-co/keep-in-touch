//
//  ManageGroupsViewModel.swift
//  KeepInTouch
//
//  Created by Codex on 2/3/26.
//

import Foundation

@MainActor
final class ManageGroupsViewModel: ObservableObject {
    @Published private(set) var groups: [Group] = []
    @Published private(set) var countsByGroup: [UUID: Int] = [:]

    private let groupRepository: GroupRepository
    private let personRepository: PersonRepository

    init(
        groupRepository: GroupRepository = CoreDataGroupRepository(context: CoreDataStack.shared.viewContext),
        personRepository: PersonRepository = CoreDataPersonRepository(context: CoreDataStack.shared.viewContext)
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
            if lhs.isDefault != rhs.isDefault { return lhs.isDefault }
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        let people = personRepository.fetchTracked(includePaused: true)
        var counts: [UUID: Int] = [:]
        for person in people {
            let groupId = person.groupId
            counts[groupId, default: 0] += 1
        }
        countsByGroup = counts
    }

    func save(_ group: Group, makeDefault: Bool) {
        var updated = group
        updated.modifiedAt = Date()

        if makeDefault {
            let all = groupRepository.fetchAll()
            for existing in all where existing.id != updated.id && existing.isDefault {
                var cleared = existing
                cleared.isDefault = false
                cleared.modifiedAt = Date()
                do {
                    try groupRepository.save(cleared)
                } catch let error as RepositoryError {
                    AppLogger.logError(error, category: AppLogger.viewModel, context: "ManageGroupsViewModel.save.clearDefault")
                    ErrorToastManager.shared.show(AppError(message: error.userMessage))
                } catch {
                    AppLogger.logError(error, category: AppLogger.viewModel, context: "ManageGroupsViewModel.save.clearDefault (unexpected)")
                    ErrorToastManager.shared.show(.saveFailed("ManageGroups"))
                }
            }
            updated.isDefault = true
        }

        do {
            try groupRepository.save(updated)
        } catch let error as RepositoryError {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "ManageGroupsViewModel.save")
            ErrorToastManager.shared.show(AppError(message: error.userMessage))
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "ManageGroupsViewModel.save (unexpected)")
            ErrorToastManager.shared.show(.saveFailed("ManageGroups"))
        }
        load()
    }

    func delete(group: Group) {
        // Enforce: reassign any remaining people to default group before deleting
        if let fallback = groups.first(where: { $0.isDefault && $0.id != group.id })
            ?? groups.first(where: { $0.id != group.id }) {
            movePeople(from: group, to: fallback)
        }
        do {
            try groupRepository.delete(id: group.id)
        } catch let error as RepositoryError {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "ManageGroupsViewModel.delete")
            ErrorToastManager.shared.show(AppError(message: error.userMessage))
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "ManageGroupsViewModel.delete (unexpected)")
            ErrorToastManager.shared.show(.deleteFailed("ManageGroups"))
        }
        load()
    }

    func movePeople(from group: Group, to defaultGroup: Group) {
        let people = personRepository.fetchByGroup(id: group.id, includePaused: true)
        guard !people.isEmpty else { return }
        let now = Date()
        let updatedPeople = people.map { person -> Person in
            var updated = person
            updated.groupId = defaultGroup.id
            updated.groupAddedAt = now
            updated.modifiedAt = now
            return updated
        }
        do {
            try personRepository.batchSave(updatedPeople)
        } catch let error as RepositoryError {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "ManageGroupsViewModel.movePeople")
            ErrorToastManager.shared.show(AppError(message: error.userMessage))
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "ManageGroupsViewModel.movePeople (unexpected)")
            ErrorToastManager.shared.show(.saveFailed("ManageGroups"))
        }
    }

    func defaultGroup() -> Group? {
        groups.first(where: { $0.isDefault })
    }
}
