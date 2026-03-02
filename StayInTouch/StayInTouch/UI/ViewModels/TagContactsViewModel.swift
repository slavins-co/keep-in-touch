//
//  TagContactsViewModel.swift
//  KeepInTouch
//
//  Created by Codex on 2/3/26.
//

import Foundation

@MainActor
final class TagContactsViewModel: ObservableObject {
    @Published private(set) var people: [Person] = []
    @Published private(set) var available: [Person] = []

    private let tag: Tag
    private let personRepository: PersonRepository
    private var allPeople: [Person] = []

    init(tag: Tag, personRepository: PersonRepository = CoreDataPersonRepository(context: CoreDataStack.shared.viewContext)) {
        self.tag = tag
        self.personRepository = personRepository
        load()
    }

    func load() {
        allPeople = personRepository.fetchTracked(includePaused: true)
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        people = allPeople.filter { $0.tagIds.contains(tag.id) }
        available = allPeople.filter { !$0.tagIds.contains(tag.id) }
    }

    func removeTag(from person: Person) {
        var updated = person
        updated.tagIds = updated.tagIds.filter { $0 != tag.id }
        updated.modifiedAt = Date()
        do {
            try personRepository.save(updated)
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "TagContactsViewModel.removeTag")
            ErrorToastManager.shared.show(.saveFailed("TagContacts"))
        }
        NotificationCenter.default.post(name: .personDidChange, object: updated.id)
        load()
    }

    func addTag(to personIds: [UUID]) {
        for person in allPeople where personIds.contains(person.id) {
            var updated = person
            if !updated.tagIds.contains(tag.id) {
                updated.tagIds.append(tag.id)
            }
            updated.modifiedAt = Date()
            do {
                try personRepository.save(updated)
            } catch {
                AppLogger.logError(error, category: AppLogger.viewModel, context: "TagContactsViewModel.addTag")
                ErrorToastManager.shared.show(.saveFailed("TagContacts"))
            }
            NotificationCenter.default.post(name: .personDidChange, object: updated.id)
        }
        load()
    }
}
