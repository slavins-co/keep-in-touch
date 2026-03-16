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
        // Remove group references from persons first, then delete entity
        // This order prevents orphaned groupId references on crash
        removeGroupFromPeople(groupId: group.id)
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
        do {
            try personRepository.batchSave(updatedPeople)
        } catch let error as RepositoryError {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "ManageGroupsViewModel.removeGroupFromPeople")
            ErrorToastManager.shared.show(AppError(message: error.userMessage))
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "ManageGroupsViewModel.removeGroupFromPeople (unexpected)")
            ErrorToastManager.shared.show(.saveFailed("ManageGroups"))
        }
    }
}
