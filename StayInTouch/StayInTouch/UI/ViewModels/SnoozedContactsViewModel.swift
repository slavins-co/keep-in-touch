//
//  SnoozedContactsViewModel.swift
//  KeepInTouch
//
//  Mirrors PausedContactsViewModel for snoozed contacts (#334). Un-snooze is
//  a one-tap clear (no last-touch date prompt, unlike resume-from-pause).
//

import Foundation

@MainActor
final class SnoozedContactsViewModel: ObservableObject, ViewModelErrorHandling {
    @Published private(set) var people: [Person] = []

    private let personRepository: PersonRepository
    /// Evaluated fresh on every `load()` so a snooze that expires while the
    /// screen is open drops off on the next `.onAppear`, staying consistent
    /// with the Settings badge (which reads `Date()` each refresh). Injectable
    /// for deterministic tests.
    private let now: () -> Date

    init(
        personRepository: PersonRepository = AppDependencies.shared.personRepository,
        now: @escaping () -> Date = { Date() }
    ) {
        self.personRepository = personRepository
        self.now = now
        load()
    }

    convenience init(dependencies: AppDependencies) {
        self.init(personRepository: dependencies.personRepository)
    }

    func load() {
        // Only *actively* snoozed people — an expired snooze is effectively
        // un-snoozed. Paused-and-snoozed people still appear here; snooze is
        // the dimension this screen manages.
        let referenceDate = now()
        people = personRepository.fetchTracked(includePaused: true)
            .filter { person in
                guard let snoozedUntil = person.snoozedUntil else { return false }
                return snoozedUntil > referenceDate
            }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func unsnooze(_ person: Person) {
        var updated = person
        updated.snoozedUntil = nil
        updated.modifiedAt = Date()
        handleWrite("SnoozedContactsViewModel.unsnooze", fallback: .saveFailed("SnoozedContacts")) {
            try personRepository.save(updated)
        }
        NotificationCenter.default.post(name: .personDidChange, object: updated.id)
    }

    func unsnooze(_ people: [Person]) {
        for person in people {
            unsnooze(person)
        }
        load()
    }
}
