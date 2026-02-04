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

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Stay in Touch")
                    .font(.largeTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                }
            }

            HStack(spacing: 12) {
                statusCount(color: "FF3B30", text: "\(viewModel.overduePeople.count) overdue")
                statusCount(color: "FF9500", text: "\(viewModel.dueSoonPeople.count) due soon")
                statusCount(color: "34C759", text: "\(viewModel.allGoodPeople.count) all good")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func statusCount(color: String, text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: color))
                .frame(width: 8, height: 8)
            Text(text)
        }
    }

    private var filters: some View {
        HStack(spacing: 8) {
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
        .padding(.bottom, 8)
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
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.overduePeople.isEmpty && viewModel.dueSoonPeople.isEmpty && viewModel.allGoodPeople.isEmpty {
                    if viewModel.searchText.isEmpty {
                        EmptyStateView(
                            title: "No friends yet",
                            message: "It's okay. We'll help you fix that.",
                            emoji: "🥲",
                            actionTitle: "Add Contacts",
                            action: { addContactsFromEmptyState() }
                        )
                    } else {
                        EmptyStateView(
                            title: "No contacts found",
                            message: "Try a different search.",
                            emoji: "🔍"
                        )
                    }
                } else if viewModel.sortOption == .name {
                    let groupsById = Dictionary(uniqueKeysWithValues: viewModel.groups.map { ($0.id, $0) })
                    let tagsById = Dictionary(uniqueKeysWithValues: viewModel.tags.map { ($0.id, $0) })
                    let calculator = SLACalculator()
                    VStack(spacing: 8) {
                        ForEach(viewModel.nameSortedPeople, id: \.id) { person in
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
            .padding(.bottom, 24)
        }
        .refreshable {
            await viewModel.refreshFromContacts()
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(
                "Search contacts...",
                text: Binding(
                    get: { viewModel.searchText },
                    set: { viewModel.updateSearchText($0) }
                )
            )
                .textFieldStyle(.plain)
            if !viewModel.searchText.isEmpty {
                Button("Clear") { viewModel.updateSearchText("") }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    private func toggleSection(_ key: String) {
        if collapsedSections.contains(key) {
            collapsedSections.remove(key)
        } else {
            collapsedSections.insert(key)
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
        return parts.joined(separator: " • ")
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
