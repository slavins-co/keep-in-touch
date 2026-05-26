//
//  ContactsListView.swift
//  KeepInTouch
//

import SwiftUI

struct ContactsListView: View {
    @ObservedObject var viewModel: HomeViewModel
    @ObservedObject var selectionCoordinator: SelectionCoordinator
    var recentGroups: [RecentGroup]
    var selectPerson: (Person) -> Void

    // Derived list state (filteredPeople, sections, sectionLetters) lives on
    // the view model so it only recomputes when its inputs (allPeople,
    // searchText) actually change — not on every body render (audit E2, #317).
    @StateObject private var listViewModel = ContactsListViewModel()

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
            } else if listViewModel.filteredPeople.isEmpty {
                Spacer()
                EmptyStateView(
                    title: "No contacts found",
                    message: "Try a different search.",
                    systemImage: "magnifyingglass"
                )
                Spacer()
                contactsSearchBar
            } else {
                contactsList
                    .overlay(alignment: .bottom) {
                        contactsSearchBar
                    }
            }
        }
        .onAppear {
            // Subscribing here (rather than in `init`) lets the view model
            // bind to the injected `HomeViewModel` once the view is mounted.
            // Safe to call repeatedly — `bind` replaces its prior cancellables.
            listViewModel.bind(to: viewModel)
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
            Text("\(listViewModel.filteredPeople.count) Contacts")
                .font(DS.Typography.homeSubtitle)
                .foregroundStyle(Color(.secondaryLabel))
            Spacer()
            Button {
                if selectionCoordinator.isSelectMode {
                    selectionCoordinator.exit()
                } else {
                    selectionCoordinator.enter(origin: .people)
                    AnalyticsService.track("bulk_log.opened", parameters: ["origin": "people"])
                }
            } label: {
                Text(selectionCoordinator.isSelectMode ? "Cancel" : "Select")
                    .font(DS.Typography.filterLabel)
                    .foregroundStyle(DS.Colors.filterAccent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(selectionCoordinator.isSelectMode ? "Exit selection mode" : "Enter selection mode")
            .accessibilityHint("Selects multiple contacts to log a group connection")
        }
        .padding(.horizontal)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.secondaryBackground)
    }

    // MARK: - Contacts List

    private var contactsList: some View {
        let calculator = FrequencyCalculator()
        // Dict lookups: O(1) per row instead of the previous O(M) linear
        // scan through `viewModel.cadences`/`groups` per row (audit E3, #317).
        let cadencesById = viewModel.cadencesById
        let groupsById = viewModel.groupsById

        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                    if selectionCoordinator.isSelectMode && !recentGroups.isEmpty {
                        RecentGroupsSection(
                            groups: recentGroups,
                            peopleById: Dictionary(uniqueKeysWithValues: viewModel.allPeople.map { ($0.id, $0) }),
                            onSelect: selectionCoordinator.chooseRecentGroup
                        )
                    }

                    ForEach(listViewModel.sections) { section in
                        Section {
                            ForEach(Array(section.people.enumerated()), id: \.element.id) { index, person in
                                let frequencyName = cadencesById[person.cadenceId]?.name ?? "Frequency"
                                let personGroups = person.groupIds.compactMap { groupsById[$0] }
                                let inSelectMode = selectionCoordinator.isSelectMode
                                Button {
                                    if inSelectMode {
                                        selectionCoordinator.toggleWithHaptic(person.id)
                                    } else {
                                        selectPerson(person)
                                    }
                                } label: {
                                    ContactCard(
                                        person: person,
                                        frequencyName: frequencyName,
                                        status: calculator.status(for: person, cadencesById: cadencesById),
                                        daysOverdue: calculator.daysOverdue(for: person, cadencesById: cadencesById),
                                        timeAgo: calculator.timeAgoText(for: person),
                                        lastMethod: person.lastTouchMethod,
                                        groups: personGroups,
                                        isSelected: inSelectMode ? selectionCoordinator.contains(person.id) : nil
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint(inSelectMode
                                                   ? "Toggles selection"
                                                   : "Opens contact details")
                                .simultaneousGesture(
                                    LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                                        if !selectionCoordinator.isSelectMode {
                                            selectionCoordinator.enter(origin: .people, preselect: person.id)
                                        }
                                    }
                                )
                                .padding(.leading)
                                .padding(.trailing, 36)

                                Rectangle()
                                    .fill(DS.Colors.rowSeparator)
                                    .frame(height: 1)
                                    .padding(.leading, 64)
                                    .accessibilityHidden(true)
                            }
                        } header: {
                            sectionHeader(letter: section.letter)
                                .id(section.letter)
                        }
                    }
                }
                .padding(.bottom, 80)
                // LazyVStack caches across sections; rebuild the whole
                // list when select mode flips so checkmark overlays don't
                // come from a stale cached row.
                .id(selectionCoordinator.isSelectMode)
            }
            .background(DS.Colors.pageBg)
            .overlay(alignment: .trailing) {
                if !selectionCoordinator.isSelectMode {
                    SectionIndexView(sections: listViewModel.sectionLetters) { letter in
                        withAnimation {
                            proxy.scrollTo(letter, anchor: .top)
                        }
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
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DS.Colors.rowSeparator)
                .frame(height: 1)
        }
        .accessibilityLabel("Section \(letter)")
    }

    // MARK: - Search Bar

    private var contactsSearchBar: some View {
        FloatingSearchBar(text: Binding(
            get: { listViewModel.searchText },
            set: { listViewModel.updateSearchText($0) }
        ))
    }

}
