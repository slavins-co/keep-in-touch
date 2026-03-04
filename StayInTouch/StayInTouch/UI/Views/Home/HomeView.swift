//
//  HomeView.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

struct HomeView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject var viewModel: HomeViewModel
    var selectPerson: (Person) -> Void
    @StateObject private var settingsViewModel = SettingsViewModel()
    @State private var collapsedSections: Set<String> = ["all-good"]
    @State private var showNewContactsPicker = false
    @State private var showNoNewContactsAlert = false
    @State private var showLimitedAccessAlert = false
    @State private var isSyncingContacts = false
    @State private var showContactsSettingsAlert = false
    @FocusState private var isSearchFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                header
                summaryCards
                filters
            }
            .background(DS.Colors.secondaryBackground)

            content
                .overlay(alignment: .bottom) {
                    floatingSearchBar
                }
        }
        .onChange(of: viewModel.selectedGroupId) { _, newValue in
            if newValue != nil {
                AnalyticsService.track("filter.applied", parameters: ["type": "frequency"])
            }
            withAnimation(.easeInOut(duration: 0.25)) {
                viewModel.applyFilters()
            }
        }
        .onChange(of: viewModel.selectedTagId) { _, newValue in
            if newValue != nil {
                AnalyticsService.track("filter.applied", parameters: ["type": "group"])
            }
            withAnimation(.easeInOut(duration: 0.25)) {
                viewModel.applyFilters()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .personDidChange)) { _ in
            viewModel.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .contactsDidSync)) { _ in
            viewModel.load()
        }
        .sheet(isPresented: $showNewContactsPicker) {
            NewContactsPickerView(
                contacts: settingsViewModel.pendingNewContacts,
                onImport: { selected in
                    Task {
                        isSyncingContacts = true
                        await settingsViewModel.importSelectedContacts(selected)
                        isSyncingContacts = false
                    }
                    showNewContactsPicker = false
                },
                onCancel: {
                    settingsViewModel.pendingNewContacts = []
                    showNewContactsPicker = false
                }
            )
        }
        .alert("No New Contacts", isPresented: $showNoNewContactsAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You're already up to date.")
        }
        .alert("Limited Contact Access", isPresented: $showLimitedAccessAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("You've imported all the contacts you gave access to. To add more, open Settings \u{2192} Keep In Touch \u{2192} Contacts and select additional contacts or grant full access.")
        }
        .alert("Contacts Access Required", isPresented: $showContactsSettingsAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enable Contacts access in Settings to import contacts.")
        }
        .onAppear {
            viewModel.load()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: DS.Spacing.xs) {
            Text("Keep In Touch")
                .font(DS.Typography.homeTitle)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text("Keep your people close")
                .font(DS.Typography.homeSubtitle)
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.top, DS.Spacing.md)
        .padding(.bottom, DS.Spacing.sm)
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        HStack(spacing: DS.Spacing.sm) {
            StatusSummaryCard(
                count: viewModel.overduePeople.count,
                label: "Overdue",
                numberColor: DS.Colors.statusOverdue,
                backgroundColor: DS.Colors.overdueCardBackground,
                borderColor: DS.Colors.overdueCardBorder
            )

            StatusSummaryCard(
                count: viewModel.dueSoonPeople.count,
                label: "Due Soon",
                numberColor: DS.Colors.statusDueSoon,
                backgroundColor: DS.Colors.dueSoonCardBackground,
                borderColor: DS.Colors.dueSoonCardBorder
            )

            StatusSummaryCard(
                count: viewModel.allGoodPeople.count,
                label: "All Good",
                numberColor: DS.Colors.statusAllGood,
                backgroundColor: DS.Colors.allGoodCardBackground,
                borderColor: DS.Colors.allGoodCardBorder
            )
        }
        .padding(.horizontal)
        .padding(.bottom, DS.Spacing.md)
    }

    // MARK: - Filters

    private var filters: some View {
        HStack(spacing: DS.Spacing.sm) {
            frequencyFilterButton
            tagFilterButton
        }
        .padding(.horizontal)
        .padding(.bottom, DS.Spacing.md)
    }

    private var frequencyFilterButton: some View {
        let isActive = viewModel.selectedGroupId != nil
        let selectedName = viewModel.selectedGroupId.flatMap { id in
            viewModel.groups.first(where: { $0.id == id })?.name
        }
        let displayText = selectedName ?? "Frequency: All"

        return filterButton(
            displayText: displayText,
            isActive: isActive,
            onClear: { viewModel.selectedGroupId = nil }
        ) {
            Button("All Frequencies") { viewModel.selectedGroupId = nil }
            ForEach(viewModel.groups, id: \.id) { group in
                Button(group.name) { viewModel.selectedGroupId = group.id }
            }
        }
    }

    private var tagFilterButton: some View {
        let isActive = viewModel.selectedTagId != nil
        let selectedName = viewModel.selectedTagId.flatMap { id in
            viewModel.tags.first(where: { $0.id == id })?.name
        }
        let displayText = selectedName ?? "Group: All"

        return filterButton(
            displayText: displayText,
            isActive: isActive,
            onClear: { viewModel.selectedTagId = nil }
        ) {
            Button("All Groups") { viewModel.selectedTagId = nil }
            ForEach(viewModel.tags, id: \.id) { tag in
                Button(tag.name) { viewModel.selectedTagId = tag.id }
            }
        }
    }

    @ViewBuilder
    private func filterButton<MenuContent: View>(
        displayText: String,
        isActive: Bool,
        onClear: @escaping () -> Void,
        @ViewBuilder menuContent: () -> MenuContent
    ) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Menu {
                menuContent()
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Text(displayText)
                        .font(DS.Typography.filterLabel)
                        .lineLimit(1)
                    if !isActive {
                        Image(systemName: "chevron.down")
                            .font(DS.Typography.filterChevron)
                    }
                }
            }

            if isActive {
                Button { onClear() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(DS.Colors.filterAccent)
                        .padding(.leading, DS.Spacing.xs)
                        .contentShape(Rectangle())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.sm)
        .background(isActive ? DS.Colors.filterAccent.opacity(0.08) : Color.clear)
        .foregroundStyle(isActive ? DS.Colors.filterAccent : Color(.secondaryLabel))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(isActive ? DS.Colors.filterAccent : DS.Colors.separator, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Search Bar (Floating)

    private var floatingSearchBar: some View {
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
                    text: Binding(
                        get: { viewModel.searchText },
                        set: { viewModel.updateSearchText(String($0.prefix(100))) }
                    )
                )
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.updateSearchText("")
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

    // MARK: - Content

    private var content: some View {
        let calculator = FrequencyCalculator()
        let groupsById = Dictionary(uniqueKeysWithValues: viewModel.groups.map { ($0.id, $0) })
        let tagsById = Dictionary(uniqueKeysWithValues: viewModel.tags.map { ($0.id, $0) })

        return ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                if viewModel.overduePeople.isEmpty && viewModel.dueSoonPeople.isEmpty && viewModel.allGoodPeople.isEmpty {
                    if viewModel.searchText.isEmpty {
                        EmptyStateView(
                            title: "No friends yet",
                            message: "It's okay. We'll help you fix that.",
                            systemImage: "person.2.slash",
                            actionTitle: "Add Contacts",
                            action: { addContactsFromEmptyState() }
                        )
                    } else {
                        EmptyStateView(
                            title: "No contacts found",
                            message: "Try a different search.",
                            systemImage: "magnifyingglass"
                        )
                    }
                } else {
                    ContactListSection(
                        title: "Overdue",
                        people: viewModel.overduePeople,
                        isCollapsed: collapsedSections.contains("overdue"),
                        onToggle: { toggleSection("overdue") },
                        groupsById: groupsById,
                        tagsById: tagsById,
                        statusForPerson: { calculator.status(for: $0, in: viewModel.groups) },
                        daysOverdueForPerson: { calculator.daysOverdue(for: $0, in: viewModel.groups) },
                        timeAgoForPerson: { timeAgoText(for: $0, calculator: calculator) },
                        selectPerson: selectPerson
                    )

                    ContactListSection(
                        title: "Due Soon",
                        people: viewModel.dueSoonPeople,
                        isCollapsed: collapsedSections.contains("due-soon"),
                        onToggle: { toggleSection("due-soon") },
                        groupsById: groupsById,
                        tagsById: tagsById,
                        statusForPerson: { calculator.status(for: $0, in: viewModel.groups) },
                        daysOverdueForPerson: { calculator.daysOverdue(for: $0, in: viewModel.groups) },
                        timeAgoForPerson: { timeAgoText(for: $0, calculator: calculator) },
                        selectPerson: selectPerson
                    )

                    ContactListSection(
                        title: "All Good",
                        people: viewModel.allGoodPeople,
                        isCollapsed: collapsedSections.contains("all-good"),
                        onToggle: { toggleSection("all-good") },
                        groupsById: groupsById,
                        tagsById: tagsById,
                        statusForPerson: { calculator.status(for: $0, in: viewModel.groups) },
                        daysOverdueForPerson: { calculator.daysOverdue(for: $0, in: viewModel.groups) },
                        timeAgoForPerson: { timeAgoText(for: $0, calculator: calculator) },
                        selectPerson: selectPerson
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top, DS.Spacing.md)
            .padding(.bottom, 80)
        }
        .background(DS.Colors.pageBg)
        .refreshable {
            await viewModel.refreshFromContacts()
        }
    }

    // MARK: - Helpers

    private func toggleSection(_ key: String) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if collapsedSections.contains(key) {
                collapsedSections.remove(key)
            } else {
                collapsedSections.insert(key)
            }
        }
    }

    private func addContactsFromEmptyState() {
        Task {
            isSyncingContacts = true
            let count = await settingsViewModel.findNewContacts()
            isSyncingContacts = false
            if count > 0 {
                showNewContactsPicker = true
            } else if settingsViewModel.contactAccessDenied {
                showContactsSettingsAlert = true
            } else if settingsViewModel.contactAccessLimited {
                showLimitedAccessAlert = true
            } else {
                showNoNewContactsAlert = true
            }
        }
    }

    private func timeAgoText(for person: Person, calculator: FrequencyCalculator) -> String {
        let days = calculator.daysSinceLastTouch(for: person)
        guard let days else { return "No contact" }
        if days == 0 { return "Today" }
        return "\(days)d ago"
    }
}
