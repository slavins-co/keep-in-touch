//
//  ContactsListView.swift
//  KeepInTouch
//

import SwiftUI

struct ContactsListView: View {
    @ObservedObject var viewModel: HomeViewModel
    var selectPerson: (Person) -> Void
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

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
            contactsHeader

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
                    .overlay(alignment: .bottom) {
                        contactsSearchBar
                    }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .personDidChange)) { _ in
            viewModel.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .contactsDidSync)) { _ in
            viewModel.load()
        }
    }

    // MARK: - Header

    private var contactsHeader: some View {
        HStack {
            Text("\(filteredPeople.count) Contacts")
                .font(DS.Typography.homeSubtitle)
                .foregroundStyle(Color(.secondaryLabel))
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.secondaryBackground)
    }

    // MARK: - Contacts List

    private var contactsList: some View {
        let calculator = FrequencyCalculator()
        let groupsById = Dictionary(uniqueKeysWithValues: viewModel.groups.map { ($0.id, $0) })
        let tagsById = Dictionary(uniqueKeysWithValues: viewModel.tags.map { ($0.id, $0) })

        return ScrollViewReader { proxy in
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
                                .padding(.leading)
                                .padding(.trailing, 36)

                                if index < section.people.count - 1 {
                                    SubtleDivider()
                                        .padding(.leading, DS.Spacing.lg)
                                        .padding(.leading)
                                        .padding(.trailing, 36)
                                }
                            }
                        } header: {
                            sectionHeader(letter: section.letter)
                                .id(section.letter)
                        }
                    }
                }
                .padding(.bottom, 80)
            }
            .background(DS.Colors.pageBg)
            .overlay(alignment: .trailing) {
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
        .padding(.leading)
        .padding(.trailing, 36)
        .background(DS.Colors.pageBg)
    }

    // MARK: - Search Bar

    private var contactsSearchBar: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [DS.Colors.pageBg.opacity(0), DS.Colors.pageBg],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 20)

            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DS.Colors.searchBarIcon)
                TextField(
                    "Search contacts...",
                    text: $searchText
                )
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DS.Colors.tertiaryText)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(DS.Colors.searchBarBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        isSearchFocused
                            ? (colorScheme == .dark ? Color(.systemGray3) : DS.Colors.filterAccent)
                            : Color(.systemGray5),
                        lineWidth: isSearchFocused ? 2 : 1
                    )
            )
            .shadow(
                color: colorScheme == .dark ? .clear : .black.opacity(0.1),
                radius: 8,
                y: 2
            )
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(DS.Colors.pageBg)
        }
    }

    // MARK: - Helpers

    private func timeAgoText(for person: Person, calculator: FrequencyCalculator) -> String {
        let days = calculator.daysSinceLastTouch(for: person)
        guard let days else { return "No contact" }
        if days == 0 { return "Today" }
        return "\(days)d ago"
    }
}
