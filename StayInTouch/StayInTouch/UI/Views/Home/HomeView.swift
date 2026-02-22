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
    @State private var isSyncingContacts = false
    @State private var showContactsSettingsAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                filters
                content
            }
        }
        .searchable(
            text: Binding(
                get: { viewModel.searchText },
                set: { viewModel.updateSearchText($0) }
            ),
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search contacts..."
        )
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
            Text(noContactsAlertMessage())
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

    private func statusCountText(count: Int, label: String, color: Color) -> Text {
        Text("\(count)").foregroundColor(color) + Text(" \(label)").foregroundColor(DS.Colors.secondaryText)
    }

    // MARK: - Filters

    private var filters: some View {
        HStack(spacing: DS.Spacing.sm) {
            Menu {
                Button("All") { viewModel.selectedGroupId = nil }
                ForEach(viewModel.groups, id: \.id) { group in
                    Button(group.name) { viewModel.selectedGroupId = group.id }
                }
            } label: {
                filterLabel(text: viewModel.selectedGroupId.flatMap { id in
                    viewModel.groups.first(where: { $0.id == id })?.name
                } ?? "All")
            }

            Menu {
                ForEach(HomeViewModel.SortOption.allCases, id: \.self) { option in
                    Button(option.rawValue) { viewModel.sortOption = option }
                }
            } label: {
                filterLabel(text: viewModel.sortOption.rawValue)
            }

            Menu {
                Button("All Tags") { viewModel.selectedTagId = nil }
                ForEach(viewModel.tags, id: \.id) { tag in
                    Button(tag.name) { viewModel.selectedTagId = tag.id }
                }
            } label: {
                filterLabel(text: viewModel.selectedTagId.flatMap { id in
                    viewModel.tags.first(where: { $0.id == id })?.name
                } ?? "All Tags")
            }
        }
        .padding(.horizontal)
        .padding(.bottom, DS.Spacing.sm)
    }

    private func filterLabel(text: String) -> some View {
        HStack {
            Text(text)
                .font(.callout)
            Spacer()
            Image(systemName: "chevron.down")
                .font(.footnote)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .overlay(Capsule().stroke(DS.Colors.separator, lineWidth: 0.5))
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
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
                    let groupsById = Dictionary(uniqueKeysWithValues: viewModel.groups.map { ($0.id, $0) })
                    let tagsById = Dictionary(uniqueKeysWithValues: viewModel.tags.map { ($0.id, $0) })
                    let calculator = SLACalculator()
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.nameSortedPeople.enumerated()), id: \.element.id) { index, person in
                            let groupName = groupsById[person.groupId]?.name ?? "Group"
                            let tags = person.tagIds.compactMap { tagsById[$0] }
                            NavigationLink {
                                PersonDetailView(person: person)
                            } label: {
                                ContactCard(
                                    person: person,
                                    groupName: groupName,
                                    tags: tags,
                                    status: calculator.status(for: person, in: viewModel.groups),
                                    daysOverdue: calculator.daysOverdue(for: person, in: viewModel.groups),
                                    metadataText: metadataText(
                                        for: person,
                                        groupName: groupName,
                                        status: calculator.status(for: person, in: viewModel.groups),
                                        includeStatus: true
                                    )
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
                    let groupsById = Dictionary(uniqueKeysWithValues: viewModel.groups.map { ($0.id, $0) })
                    let tagsById = Dictionary(uniqueKeysWithValues: viewModel.tags.map { ($0.id, $0) })
                    let calculator = SLACalculator()

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
                        metadataTextForPerson: {
                            let groupName = groupsById[$0.groupId]?.name ?? "Group"
                            return metadataText(
                                for: $0,
                                groupName: groupName,
                                status: calculator.status(for: $0, in: viewModel.groups),
                                includeStatus: false
                            )
                        }
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
                        metadataTextForPerson: {
                            let groupName = groupsById[$0.groupId]?.name ?? "Group"
                            return metadataText(
                                for: $0,
                                groupName: groupName,
                                status: calculator.status(for: $0, in: viewModel.groups),
                                includeStatus: false
                            )
                        }
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
                        metadataTextForPerson: {
                            let groupName = groupsById[$0.groupId]?.name ?? "Group"
                            return metadataText(
                                for: $0,
                                groupName: groupName,
                                status: calculator.status(for: $0, in: viewModel.groups),
                                includeStatus: false
                            )
                        }
                    )
                }
            }
            .padding(.horizontal)
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
            } else {
                if settingsViewModel.contactAccessDenied {
                    showContactsSettingsAlert = true
                } else {
                    showNoNewContactsAlert = true
                }
            }
        }
    }

    private func noContactsAlertMessage() -> String {
        "You're already up to date."
    }

    private func metadataText(for person: Person, groupName: String, status: SLAStatus, includeStatus: Bool) -> String {
        var parts: [String] = [groupName]
        if includeStatus {
            parts.append(statusLabel(status))
        }
        parts.append(timeAgoText(for: person))
        if let method = person.lastTouchMethod {
            parts.append(method.rawValue)
        }
        return parts.joined(separator: " \u{2022} ")
    }

    private func timeAgoText(for person: Person) -> String {
        let days = SLACalculator().daysSinceLastTouch(for: person)
        guard let days else { return "No touch" }
        if days == 0 { return "Today" }
        return "\(days)d ago"
    }

    private func statusLabel(_ status: SLAStatus) -> String {
        switch status {
        case .inSLA: return "All good"
        case .dueSoon: return "Check in soon"
        case .outOfSLA: return "Overdue"
        case .unknown: return "Unknown"
        }
    }
}
