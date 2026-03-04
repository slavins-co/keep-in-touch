//
//  ContactsListView.swift
//  KeepInTouch
//

import SwiftUI

struct ContactsListView: View {
    @ObservedObject var viewModel: HomeViewModel
    var selectPerson: (Person) -> Void
    @State private var searchText = ""

    // MARK: - Computed Data

    private var filteredPeople: [Person] {
        let people = viewModel.allPeople
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return people.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
        }
        return people.filter {
            $0.displayName.lowercased().contains(query)
        }.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    private var sections: [(letter: String, people: [Person])] {
        let grouped = Dictionary(grouping: filteredPeople) { person -> String in
            let first = person.displayName.prefix(1).uppercased()
            return first.rangeOfCharacter(from: .letters) != nil ? first : "#"
        }
        return grouped.sorted { $0.key < $1.key }
            .map { (letter: $0.key, people: $0.value) }
    }

    private var sectionLetters: [String] {
        sections.map(\.letter)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.allPeople.isEmpty {
                Spacer()
                EmptyStateView(
                    title: "No contacts yet",
                    message: "Import contacts from Settings to get started.",
                    systemImage: "person.2.slash"
                )
                Spacer()
            } else if filteredPeople.isEmpty {
                Spacer()
                EmptyStateView(
                    title: "No contacts found",
                    message: "Try a different search.",
                    systemImage: "magnifyingglass"
                )
                Spacer()
            } else {
                contactsList
            }

            contactsSearchBar
        }
        .onReceive(NotificationCenter.default.publisher(for: .personDidChange)) { _ in
            viewModel.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .contactsDidSync)) { _ in
            viewModel.load()
        }
    }

    // MARK: - Contacts List

    private var contactsList: some View {
        let calculator = FrequencyCalculator()
        let groupsById = Dictionary(uniqueKeysWithValues: viewModel.groups.map { ($0.id, $0) })
        let tagsById = Dictionary(uniqueKeysWithValues: viewModel.tags.map { ($0.id, $0) })

        return ScrollViewReader { proxy in
            ZStack(alignment: .trailing) {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                        ForEach(sections, id: \.letter) { section in
                            Section {
                                ForEach(Array(section.people.enumerated()), id: \.element.id) { index, person in
                                    let frequencyName = groupsById[person.groupId]?.name ?? "Frequency"
                                    let firstTagName = person.tagIds.compactMap { tagsById[$0]?.name }.first
                                    Button {
                                        selectPerson(person)
                                    } label: {
                                        ContactCard(
                                            person: person,
                                            frequencyName: frequencyName,
                                            status: calculator.status(for: person, in: viewModel.groups),
                                            daysOverdue: calculator.daysOverdue(for: person, in: viewModel.groups),
                                            timeAgo: timeAgoText(for: person, calculator: calculator),
                                            lastMethod: person.lastTouchMethod,
                                            tagName: firstTagName
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    if index < section.people.count - 1 {
                                        SubtleDivider()
                                            .padding(.leading, DS.Spacing.lg)
                                    }
                                }
                            } header: {
                                sectionHeader(letter: section.letter)
                                    .id(section.letter)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, DS.Spacing.sm)
                }

                SectionIndexView(sections: sectionLetters) { letter in
                    withAnimation {
                        proxy.scrollTo(letter, anchor: .top)
                    }
                }
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(letter: String) -> some View {
        HStack {
            Text(letter)
                .font(DS.Typography.sectionHeaderMono)
                .foregroundStyle(Color(.secondaryLabel))
            Spacer()
        }
        .padding(.vertical, DS.Spacing.xs)
        .padding(.horizontal, DS.Spacing.xs)
        .background(DS.Colors.background)
    }

    // MARK: - Search Bar

    private var contactsSearchBar: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DS.Colors.tertiaryText)
            TextField(
                "Search contacts...",
                text: $searchText
            )
            .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DS.Colors.tertiaryText)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.secondaryBackground)
        .clipShape(Capsule())
        .padding(.horizontal)
        .padding(.bottom, DS.Spacing.sm)
    }

    // MARK: - Helpers

    private func timeAgoText(for person: Person, calculator: FrequencyCalculator) -> String {
        let days = calculator.daysSinceLastTouch(for: person)
        guard let days else { return "No contact" }
        if days == 0 { return "Today" }
        return "\(days)d ago"
    }
}
