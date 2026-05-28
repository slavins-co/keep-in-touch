//
//  ContactsListViewModel.swift
//  KeepInTouch
//
//  Owns the derived state for the Contacts tab: the alphabetically-sorted
//  filtered list, its A–Z section grouping, and the section-letter index.
//
//  Previously these lived as plain computed properties on
//  `ContactsListView`, so every body render walked the full contact list
//  twice (`filter` + `sort`) and ran `Dictionary(grouping:)` to bucket
//  into sections. With `HomeViewModel` published changes churning at
//  high frequency, that turned the Contacts tab into an O(N log N) hot
//  path on every render (audit E2, #317).
//
//  Per Apple's "Managing model data in your app" guidance, derived state
//  belongs in the view model, not in `body`. Inputs are:
//    1. `HomeViewModel.allPeople` (observed via Combine `sink`)
//    2. local `searchText` (assigned via `updateSearchText`)
//  Any other input that begins to feed the list MUST be wired here or
//  the displayed contacts will go stale.
//

import Foundation
import Combine

@MainActor
final class ContactsListViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published private(set) var filteredPeople: [Person] = []
    @Published private(set) var sections: [ContactsSection] = []
    @Published private(set) var sectionLetters: [String] = []

    private weak var homeViewModel: HomeViewModel?
    private var cancellables: Set<AnyCancellable> = []

    struct ContactsSection: Equatable, Identifiable {
        let letter: String
        let people: [Person]
        var id: String { letter }
    }

    init() {}

    /// Wires the upstream `HomeViewModel.allPeople` and local `searchText`
    /// publishers so the derived list stays in sync. Idempotent — calling
    /// twice with the same instance re-subscribes (safe: the prior
    /// `cancellables` set is replaced).
    func bind(to homeViewModel: HomeViewModel) {
        self.homeViewModel = homeViewModel
        cancellables = []

        // CombineLatest keeps both inputs in scope so the first emission
        // (after subscription) carries the current allPeople and the
        // current searchText, not a default empty value.
        homeViewModel.$allPeople
            .combineLatest($searchText)
            .sink { [weak self] people, query in
                self?.recompute(from: people, query: query)
            }
            .store(in: &cancellables)
    }

    func updateSearchText(_ text: String) {
        searchText = text
    }

    // MARK: - Private

    private func recompute(from people: [Person], query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered: [Person]
        if trimmed.isEmpty {
            filtered = people
        } else {
            filtered = people.filter {
                $0.displayName.lowercased().contains(trimmed) ||
                ($0.nickname?.lowercased().contains(trimmed) ?? false)
            }
        }
        let sorted = filtered.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }

        let grouped = Dictionary(grouping: sorted) { person -> String in
            let first = person.displayName.prefix(1).uppercased()
            return first.rangeOfCharacter(from: .letters) != nil ? first : "#"
        }
        let newSections = grouped
            .sorted { $0.key < $1.key }
            .map { ContactsSection(letter: $0.key, people: $0.value) }

        filteredPeople = sorted
        sections = newSections
        sectionLetters = newSections.map(\.letter)
    }
}
