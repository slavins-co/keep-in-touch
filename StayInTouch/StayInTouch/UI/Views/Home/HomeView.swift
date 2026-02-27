//
//  HomeView.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

struct HomeView: View {
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var settingsViewModel = SettingsViewModel()
    @State private var collapsedSections: Set<String> = ["all-good"]
    @State private var deepLinkPerson: Person?
    @State private var showNewContactsPicker = false
    @State private var showNoNewContactsAlert = false
    @State private var showLimitedAccessAlert = false
    @State private var isSyncingContacts = false
    @State private var showContactsSettingsAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    header
                    filters
                }
                .background(DS.Colors.secondaryBackground)

                content
                searchBar
            }
        }
        .onChange(of: viewModel.selectedGroupId) { _, _ in
            viewModel.applyFilters()
        }
        .onChange(of: viewModel.selectedTagId) { _, _ in
            viewModel.applyFilters()
        }
        .onChange(of: viewModel.sortOption) { _, _ in
            viewModel.applyFilters()
        }
        .onReceive(NotificationCenter.default.publisher(for: .personDidChange)) { _ in
            viewModel.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .contactsDidSync)) { _ in
            viewModel.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .notificationDeepLink)) { notification in
            handleDeepLink(notification.userInfo)
        }
        .sheet(item: $deepLinkPerson) { person in
            PersonDetailView(person: person)
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
            Text("You've imported all the contacts you gave access to. To add more, open Settings \u{2192} Stay in Touch \u{2192} Contacts and select additional contacts or grant full access.")
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
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text("Stay in Touch")
                    .font(DS.Typography.largeTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title3)
                }
            }

            HStack(spacing: DS.Spacing.sm) {
                statusCountText(count: viewModel.overduePeople.count, label: "overdue", color: DS.Colors.statusOverdue)
                Text("\u{00B7}").foregroundStyle(DS.Colors.tertiaryText)
                statusCountText(count: viewModel.dueSoonPeople.count, label: "due soon", color: DS.Colors.statusDueSoon)
                Text("\u{00B7}").foregroundStyle(DS.Colors.tertiaryText)
                statusCountText(count: viewModel.allGoodPeople.count, label: "all good", color: DS.Colors.statusAllGood)
            }
            .font(DS.Typography.caption)
        }
        .padding(.horizontal)
        .padding(.top, DS.Spacing.md)
        .padding(.bottom, DS.Spacing.sm)
    }

    @ViewBuilder
    private func statusCountText(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 0) {
            Text("\(count)")
                .foregroundColor(color)
                .contentTransition(.numericText())
            Text(" \(label)")
                .foregroundColor(DS.Colors.secondaryText)
        }
        .animation(.easeInOut(duration: 0.3), value: count)
    }

    // MARK: - Filters

    private var filters: some View {
        FlowLayout(spacing: DS.Spacing.sm) {
            // Sort control (icon only)
            Menu {
                ForEach(HomeViewModel.SortOption.allCases, id: \.self) { option in
                    Button {
                        viewModel.sortOption = option
                    } label: {
                        if viewModel.sortOption == option {
                            Label("Sort by \(option.rawValue)", systemImage: "checkmark")
                        } else {
                            Text("Sort by \(option.rawValue)")
                        }
                    }
                }
            } label: {
                Image(systemName: viewModel.sortOption == .name
                      ? "line.3.horizontal.decrease.circle.fill"
                      : "line.3.horizontal.decrease.circle")
                    .font(.title3)
                    .foregroundStyle(viewModel.sortOption == .name ? DS.Colors.accent : DS.Colors.secondaryText)
            }

            // Frequency filter chip
            frequencyFilterChip

            // Tag filter chip
            tagFilterChip
        }
        .padding(.horizontal)
        .padding(.bottom, DS.Spacing.md)
    }

    private var frequencyFilterChip: some View {
        let isActive = viewModel.selectedGroupId != nil
        let displayText = viewModel.selectedGroupId.flatMap { id in
            viewModel.groups.first(where: { $0.id == id })?.name
        } ?? "Frequency"

        return HStack(spacing: DS.Spacing.xs) {
            Menu {
                Button("All Frequencies") { viewModel.selectedGroupId = nil }
                ForEach(viewModel.groups, id: \.id) { group in
                    Button(group.name) { viewModel.selectedGroupId = group.id }
                }
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Text(displayText)
                        .font(.subheadline)
                        .lineLimit(1)
                    if !isActive {
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                }
            }

            if isActive {
                Button { viewModel.selectedGroupId = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(DS.Colors.accent)
                        .frame(minWidth: 44)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, 6)
        .background(isActive ? DS.Colors.accent.opacity(0.12) : Color.clear)
        .foregroundStyle(isActive ? DS.Colors.accent : DS.Colors.secondaryText)
        .overlay(
            Capsule()
                .stroke(isActive ? Color.clear : DS.Colors.separator, lineWidth: 0.5)
        )
        .clipShape(Capsule())
    }

    private var tagFilterChip: some View {
        let isActive = viewModel.selectedTagId != nil
        let displayText = viewModel.selectedTagId.flatMap { id in
            viewModel.tags.first(where: { $0.id == id })?.name
        } ?? "Groups"

        return HStack(spacing: DS.Spacing.xs) {
            Menu {
                Button("All Groups") { viewModel.selectedTagId = nil }
                ForEach(viewModel.tags, id: \.id) { tag in
                    Button(tag.name) { viewModel.selectedTagId = tag.id }
                }
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Text(displayText)
                        .font(.subheadline)
                        .lineLimit(1)
                    if !isActive {
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                }
            }

            if isActive {
                Button { viewModel.selectedTagId = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(DS.Colors.accent)
                        .frame(minWidth: 44)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, 6)
        .background(isActive ? DS.Colors.accent.opacity(0.12) : Color.clear)
        .foregroundStyle(isActive ? DS.Colors.accent : DS.Colors.secondaryText)
        .overlay(
            Capsule()
                .stroke(isActive ? Color.clear : DS.Colors.separator, lineWidth: 0.5)
        )
        .clipShape(Capsule())
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DS.Colors.tertiaryText)
            TextField(
                "Search contacts...",
                text: Binding(
                    get: { viewModel.searchText },
                    set: { viewModel.updateSearchText($0) }
                )
            )
            .textFieldStyle(.plain)
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.updateSearchText("")
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

    // MARK: - Content

    private var content: some View {
        let calculator = FrequencyCalculator()
        let groupsById = Dictionary(uniqueKeysWithValues: viewModel.groups.map { ($0.id, $0) })
        let tagsById = Dictionary(uniqueKeysWithValues: viewModel.tags.map { ($0.id, $0) })

        return ScrollView {
            VStack(spacing: DS.Spacing.xl) {
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
                } else if viewModel.sortOption == .name {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.nameSortedPeople.enumerated()), id: \.element.id) { index, person in
                            let frequencyName = groupsById[person.groupId]?.name ?? "Frequency"
                            let tags = person.tagIds.compactMap { tagsById[$0] }
                            NavigationLink {
                                PersonDetailView(person: person)
                            } label: {
                                ContactCard(
                                    person: person,
                                    frequencyName: frequencyName,
                                    tags: tags,
                                    status: calculator.status(for: person, in: viewModel.groups),
                                    daysOverdue: calculator.daysOverdue(for: person, in: viewModel.groups),
                                    timeAgo: timeAgoText(for: person, calculator: calculator),
                                    lastMethod: person.lastTouchMethod
                                )
                            }
                            .buttonStyle(.plain)

                            if index < viewModel.nameSortedPeople.count - 1 {
                                SubtleDivider()
                                    .padding(.leading, DS.Spacing.lg)
                            }
                        }
                    }
                } else {
                    ContactListSection(
                        title: "Overdue",
                        colorHex: "FF3B30",
                        people: viewModel.overduePeople,
                        isCollapsed: collapsedSections.contains("overdue"),
                        onToggle: { toggleSection("overdue") },
                        groupsById: groupsById,
                        tagsById: tagsById,
                        statusForPerson: { calculator.status(for: $0, in: viewModel.groups) },
                        daysOverdueForPerson: { calculator.daysOverdue(for: $0, in: viewModel.groups) },
                        timeAgoForPerson: { timeAgoText(for: $0, calculator: calculator) }
                    )

                    ContactListSection(
                        title: "Due Soon",
                        colorHex: "FF9500",
                        people: viewModel.dueSoonPeople,
                        isCollapsed: collapsedSections.contains("due-soon"),
                        onToggle: { toggleSection("due-soon") },
                        groupsById: groupsById,
                        tagsById: tagsById,
                        statusForPerson: { calculator.status(for: $0, in: viewModel.groups) },
                        daysOverdueForPerson: { calculator.daysOverdue(for: $0, in: viewModel.groups) },
                        timeAgoForPerson: { timeAgoText(for: $0, calculator: calculator) }
                    )

                    ContactListSection(
                        title: "All Good",
                        colorHex: "34C759",
                        people: viewModel.allGoodPeople,
                        isCollapsed: collapsedSections.contains("all-good"),
                        onToggle: { toggleSection("all-good") },
                        groupsById: groupsById,
                        tagsById: tagsById,
                        statusForPerson: { calculator.status(for: $0, in: viewModel.groups) },
                        daysOverdueForPerson: { calculator.daysOverdue(for: $0, in: viewModel.groups) },
                        timeAgoForPerson: { timeAgoText(for: $0, calculator: calculator) }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.xxl)
        }
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

    private func handleDeepLink(_ userInfo: [AnyHashable: Any]?) {
        guard let userInfo else { return }
        let type = userInfo["type"] as? String
        if type == "person", let idString = userInfo["personId"] as? String, let id = UUID(uuidString: idString) {
            if let person = CoreDataPersonRepository(context: CoreDataStack.shared.viewContext).fetch(id: id) {
                deepLinkPerson = person
            }
        } else if type == "home" {
            selectedDefaults()
        }
    }

    private func selectedDefaults() {
        viewModel.selectedGroupId = nil
        viewModel.selectedTagId = nil
        viewModel.sortOption = .status
        viewModel.applyFilters()
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
