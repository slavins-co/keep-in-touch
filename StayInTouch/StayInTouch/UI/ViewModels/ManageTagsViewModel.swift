//
//  ManageTagsViewModel.swift
//  KeepInTouch
//
//  Created by Codex on 2/3/26.
//

import Foundation

@MainActor
final class ManageTagsViewModel: ObservableObject {
    @Published private(set) var tags: [Tag] = []
    @Published private(set) var countsByTag: [UUID: Int] = [:]

    private let tagRepository: TagRepository
    private let personRepository: PersonRepository

    init(
        tagRepository: TagRepository = CoreDataTagRepository(context: CoreDataStack.shared.viewContext),
        personRepository: PersonRepository = CoreDataPersonRepository(context: CoreDataStack.shared.viewContext)
    ) {
        self.tagRepository = tagRepository
        self.personRepository = personRepository
        load()
    }

    func load() {
        tags = tagRepository.fetchAll().sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        let people = personRepository.fetchTracked(includePaused: true)
        var counts: [UUID: Int] = [:]
        for person in people {
            for tagId in person.tagIds {
                counts[tagId, default: 0] += 1
            }
        }
        countsByTag = counts
    }

    func save(_ tag: Tag) {
        var updated = tag
        updated.modifiedAt = Date()
        do {
            try tagRepository.save(updated)
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "ManageTagsViewModel.save")
            ErrorToastManager.shared.show(.saveFailed("ManageTags"))
        }
        load()
    }

    func delete(tag: Tag) {
        // Remove tag references from persons first, then delete entity
        // This order prevents orphaned tagId references on crash
        removeTagFromPeople(tagId: tag.id)
        do {
            try tagRepository.delete(id: tag.id)
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "ManageTagsViewModel.delete")
            ErrorToastManager.shared.show(.deleteFailed("ManageTags"))
        }
        load()
    }

    func removeTagFromPeople(tagId: UUID) {
        let people = personRepository.fetchTracked(includePaused: true)
        let now = Date()
        var updatedPeople: [Person] = []
        for person in people where person.tagIds.contains(tagId) {
            var updated = person
            updated.tagIds = updated.tagIds.filter { $0 != tagId }
            updated.modifiedAt = now
            updatedPeople.append(updated)
        }
        guard !updatedPeople.isEmpty else { return }
        do {
            try personRepository.batchSave(updatedPeople)
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "ManageTagsViewModel.removeTagFromPeople")
            ErrorToastManager.shared.show(.saveFailed("ManageTags"))
        }
    }
}
