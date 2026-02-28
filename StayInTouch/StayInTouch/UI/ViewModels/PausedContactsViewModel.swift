//
//  PausedContactsViewModel.swift
//  StayInTouch
//
//  Created by Codex on 2/3/26.
//

import Foundation

@MainActor
final class PausedContactsViewModel: ObservableObject {
    @Published private(set) var people: [Person] = []

    private let personRepository: PersonRepository

    init(personRepository: PersonRepository = CoreDataPersonRepository(context: CoreDataStack.shared.viewContext)) {
        self.personRepository = personRepository
        load()
    }

    func load() {
        people = personRepository.fetchTracked(includePaused: true)
            .filter { $0.isPaused }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func resume(_ person: Person, lastTouchAt: Date?) {
        var updated = person
        updated.isPaused = false
        if let lastTouchAt {
            updated.lastTouchAt = lastTouchAt
        }
        updated.modifiedAt = Date()
        do {
            try personRepository.save(updated)
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "PausedContactsViewModel.resume")
            ErrorToastManager.shared.show(.saveFailed("PausedContacts"))
        }
        NotificationCenter.default.post(name: .personDidChange, object: updated.id)
    }

    func resume(_ people: [Person], lastTouchAt: Date?) {
        for person in people {
            resume(person, lastTouchAt: lastTouchAt)
        }
        load()
    }
}
