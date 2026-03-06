//
//  SettingsView.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel = SettingsViewModel()

    @State private var showBreachTimePicker = false
    @State private var showDigestTimePicker = false
    @State private var showDigestDayPicker = false
    @State private var shareItem: ShareItem?
    @State private var workingTime = Date()
    @State private var showNoNewContactsAlert = false
    @State private var showLimitedAccessAlert = false
    @State private var showContactsSettingsAlert = false
    @State private var showNewContactsPicker = false
    @State private var showGroupAssignment = false
    @State private var shouldShowGroupAssignment = false
    @State private var showLastTouchSeeding = false
    @State private var shouldShowLastTouchSeeding = false
    @State private var groupAssignmentsForImport: [String: UUID] = [:]
    @State private var selectedForImport: [ContactSummary] = []
    @State private var showFilePicker = false
    @State private var importPreview: ImportPreview?
    @State private var showImportPreview = false
    @State private var showImportSuccessAlert = false
    @State private var showImportErrorAlert = false
    @State private var importResultMessage = ""
    @State private var showResetFrequenciesConfirmation = false
    @State private var showPostImportMatch = false
    @State private var postImportResult: ImportResult?
    @State private var postImportMatchSummary: ContactMatchSummary?

    var body: some View {
        List {
            appearanceSection
            peopleSection
            notificationsSection
            dataSection
            aboutSection
            dangerZoneSection
        }
        .listStyle(.insetGrouped)
        .tint(DS.Colors.accent)
        .navigationTitle("Settings")
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url]) {
                try? FileManager.default.removeItem(at: item.url)
            }
        }
        .sheet(isPresented: $showBreachTimePicker) {
            timePickerSheet(
                title: "Alert Time",
                time: viewModel.settings.breachTimeOfDay,
                onSave: { viewModel.setBreachTime($0) }
            )
        }
        .sheet(isPresented: $showDigestTimePicker) {
            timePickerSheet(
                title: "Digest Time",
                time: viewModel.settings.digestTime,
                onSave: { viewModel.setDigestTime($0) }
            )
        }
        .sheet(isPresented: $showDigestDayPicker) {
            dayPickerSheet
        }
        .alert("Notifications Disabled", isPresented: $viewModel.showNotificationsSettingsAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enable notifications in iOS Settings to receive alerts.")
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
        .sheet(isPresented: $showNewContactsPicker) {
            NewContactsPickerView(
                contacts: viewModel.pendingNewContacts,
                onImport: { selected in
                    selectedForImport = selected
                    shouldShowGroupAssignment = true
                    showNewContactsPicker = false
                },
                onCancel: {
                    viewModel.pendingNewContacts = []
                    showNewContactsPicker = false
                }
            )
        }
        .sheet(isPresented: $showGroupAssignment) {
            SettingsGroupAssignmentView(
                contacts: selectedForImport,
                groups: viewModel.allGroups,
                onImport: { assignments in
                    groupAssignmentsForImport = assignments
                    shouldShowLastTouchSeeding = true
                    showGroupAssignment = false
                },
                onCancel: {
                    shouldShowLastTouchSeeding = false
                    showGroupAssignment = false
                }
            )
        }
        .sheet(isPresented: $showLastTouchSeeding) {
            SettingsLastTouchSeedingView(
                contacts: selectedForImport,
                onContinue: { lastTouchSelections in
                    Task {
                        await viewModel.importSelectedContacts(
                            selectedForImport,
                            groupAssignments: groupAssignmentsForImport,
                            lastTouchSelections: lastTouchSelections
                        )
                    }
                    showLastTouchSeeding = false
                },
                onCancel: {
                    showLastTouchSeeding = false
                }
            )
        }
        .onChange(of: showNewContactsPicker) { _, isPresented in
            if !isPresented && shouldShowGroupAssignment {
                shouldShowGroupAssignment = false
                showGroupAssignment = true
            }
        }
        .onChange(of: showGroupAssignment) { _, isPresented in
            if !isPresented && shouldShowLastTouchSeeding {
                shouldShowLastTouchSeeding = false
                showLastTouchSeeding = true
            }
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [UTType.json]) { result in
            switch result {
            case .success(let url):
                Task {
                    if let preview = await viewModel.parseImportFile(url: url) {
                        importPreview = preview
                        showImportPreview = true
                    } else {
                        importResultMessage = "Could not read the file. Make sure it is a valid Keep In Touch export."
                        showImportErrorAlert = true
                    }
                }
            case .failure:
                importResultMessage = "Could not open the file."
                showImportErrorAlert = true
            }
        }
        .sheet(isPresented: $showImportPreview) {
            if let preview = importPreview {
                ImportPreviewView(
                    preview: preview,
                    onImport: { resolvedPreview in
                        showImportPreview = false
                        Task {
                            let (result, matchSummary) = await viewModel.performFileImport(resolvedPreview)

                            if let matchSummary {
                                postImportResult = result
                                postImportMatchSummary = matchSummary
                                showPostImportMatch = true
                            } else {
                                var parts: [String] = []
                                if result.totalPeople > 0 {
                                    parts.append("\(result.totalPeople) contact\(result.totalPeople == 1 ? "" : "s")")
                                }
                                if result.groupsCreated > 0 {
                                    parts.append("\(result.groupsCreated) frequenc\(result.groupsCreated == 1 ? "y" : "ies")")
                                }
                                if result.tagsCreated > 0 {
                                    parts.append("\(result.tagsCreated) group\(result.tagsCreated == 1 ? "" : "s")")
                                }
                                importResultMessage = parts.isEmpty
                                    ? "Nothing was imported."
                                    : "Imported \(parts.joined(separator: ", ")) successfully."
                                showImportSuccessAlert = true
                            }
                        }
                    },
                    onCancel: {
                        showImportPreview = false
                    }
                )
            }
        }
        .sheet(isPresented: $showPostImportMatch) {
            if let result = postImportResult, let matchSummary = postImportMatchSummary {
                PostImportMatchView(
                    importResult: result,
                    matchSummary: matchSummary,
                    viewModel: viewModel,
                    onDismiss: { showPostImportMatch = false }
                )
            }
        }
        .alert("Import Complete", isPresented: $showImportSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importResultMessage)
        }
        .alert("Import Failed", isPresented: $showImportErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importResultMessage)
        }
        .onAppear { viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .personDidChange)) { _ in
            guard !showPostImportMatch else { return }
            viewModel.load()
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: Binding(
                get: { viewModel.settings.theme },
                set: { newTheme in viewModel.setTheme(newTheme) }
            )) {
                ForEach(Theme.allCases, id: \.self) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var peopleSection: some View {
        Section("People") {
            NavigationLink {
                ManageGroupsView()
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(DS.Colors.accent)
                    Text("Manage Frequencies")
                    Spacer()
                    Text("\(viewModel.groupsCount)")
                        .foregroundStyle(DS.Colors.secondaryText)
                }
            }

            NavigationLink {
                ManageTagsView()
            } label: {
                HStack {
                    Image(systemName: "person.3.fill")
                        .foregroundStyle(DS.Colors.accent)
                    Text("Manage Groups")
                    Spacer()
                    Text("\(viewModel.tagsCount)")
                        .foregroundStyle(DS.Colors.secondaryText)
                }
            }

            NavigationLink {
                PausedContactsView()
            } label: {
                HStack {
                    Image(systemName: "pause.circle.fill")
                        .foregroundStyle(DS.Colors.secondaryText)
                    Text("Paused Contacts")
                    Spacer()
                    Text("\(viewModel.pausedCount)")
                        .foregroundStyle(DS.Colors.secondaryText)
                }
            }

            Button {
                Task {
                    let count = await viewModel.findNewContacts()
                    if count > 0 {
                        showNewContactsPicker = true
                    } else if viewModel.contactAccessDenied {
                        showContactsSettingsAlert = true
                    } else if viewModel.contactAccessLimited {
                        showLimitedAccessAlert = true
                    } else {
                        showNoNewContactsAlert = true
                    }
                }
            } label: {
                Label("Add from Contacts", systemImage: "person.badge.plus")
            }

            if let lastSync = viewModel.settings.lastContactsSyncAt {
                Text("Last sync: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                    .font(DS.Typography.metadata)
                    .foregroundStyle(DS.Colors.secondaryText)
            }

            if viewModel.isSyncing {
                HStack(spacing: DS.Spacing.md) {
                    ProgressView()
                    Text("Checking contacts...")
                        .font(DS.Typography.metadata)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
            }
        }
    }

    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle(isOn: Binding(
                get: { viewModel.settings.notificationsEnabled },
                set: { newValue in
                    Task { await viewModel.setNotificationsEnabled(newValue) }
                }
            )) {
                Label("Daily Reminders", systemImage: "bell.fill")
                    .foregroundStyle(DS.Colors.statusDueSoon)
            }

            if viewModel.settings.notificationsEnabled {
                Button {
                    showBreachTimePicker = true
                } label: {
                    HStack {
                        Text("Reminder Time")
                        Spacer()
                        Text(viewModel.settings.breachTimeOfDay.formatted)
                            .foregroundStyle(DS.Colors.secondaryText)
                    }
                }
                .padding(.leading, DS.Spacing.lg)
            }

            Toggle(isOn: Binding(
                get: { viewModel.settings.digestEnabled },
                set: { newValue in viewModel.setDigestEnabled(newValue) }
            )) {
                Label("Weekly Digest", systemImage: "bell.badge.fill")
                    .foregroundStyle(DS.Colors.statusDueSoon)
            }

            if viewModel.settings.digestEnabled {
                Button {
                    showDigestDayPicker = true
                } label: {
                    HStack {
                        Text("Digest Day")
                        Spacer()
                        Text(viewModel.settings.digestDay.displayName)
                            .foregroundStyle(DS.Colors.secondaryText)
                    }
                }
                .padding(.leading, DS.Spacing.lg)

                Button {
                    showDigestTimePicker = true
                } label: {
                    HStack {
                        Text("Digest Time")
                        Spacer()
                        Text(viewModel.settings.digestTime.formatted)
                            .foregroundStyle(DS.Colors.secondaryText)
                    }
                }
                .padding(.leading, DS.Spacing.lg)
            }

            Picker("Reminder Grouping", selection: Binding(
                get: { viewModel.settings.notificationGrouping },
                set: { viewModel.setNotificationGrouping($0) }
            )) {
                ForEach(NotificationGrouping.allCases, id: \.self) { option in
                    Text(option.displayName).tag(option)
                }
            }

            Toggle(isOn: Binding(
                get: { viewModel.settings.badgeCountShowDueSoon },
                set: { viewModel.setBadgeCountShowDueSoon($0) }
            )) {
                Text("Include Due Soon in Badge")
            }
        }
    }

    private var dataSection: some View {
        Section("Data") {
            Button {
                if let url = viewModel.exportContacts() {
                    shareItem = ShareItem(url: url)
                }
            } label: {
                Label("Export Contacts", systemImage: "square.and.arrow.up")
            }

            Button {
                showFilePicker = true
            } label: {
                Label("Import Contacts", systemImage: "square.and.arrow.down")
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "v\(version) (\(build))"
    }

    private var aboutSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { viewModel.settings.analyticsEnabled },
                set: { viewModel.setAnalyticsEnabled($0) }
            )) {
                Label("Anonymous Usage Analytics", systemImage: "shield.checkered")
            }

            NavigationLink(destination: AdvancedSettingsView(viewModel: viewModel)) {
                Label("Advanced Settings", systemImage: "gearshape.2")
            }
        } header: {
            Text("About")
        } footer: {
            VStack(spacing: DS.Spacing.md) {
                Text("Your relationship data never leaves your phone. Anonymous usage statistics help us improve the app.")
                VStack(spacing: DS.Spacing.sm) {
                    Text("Keep In Touch \(appVersion)")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                    Text("Privacy-first personal CRM")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, DS.Spacing.sm)
            }
        }
    }

    private var dangerZoneSection: some View {
        Section {
            Button(role: .destructive) {
                showResetFrequenciesConfirmation = true
            } label: {
                Label("Fresh Start", systemImage: "arrow.counterclockwise")
            }
            .confirmationDialog(
                "Start Fresh?",
                isPresented: $showResetFrequenciesConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset the Clock", role: .destructive) {
                    Task { await viewModel.resetAllFrequencies() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Been away for a while? No worries \u{2014} this resets the clock on all your contacts so everything starts clean from today. Your touch history, groups, and frequencies are all preserved.")
            }
        } header: {
            Text("Danger Zone")
                .foregroundStyle(DS.Colors.destructive)
        }
    }

    private func timePickerSheet(title: String, time: LocalTime, onSave: @escaping (LocalTime) -> Void) -> some View {
        NavigationStack {
            DatePicker(
                title,
                selection: $workingTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismissSheets() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(LocalTime.from(date: workingTime))
                        dismissSheets()
                    }
                }
            }
            .onAppear { workingTime = time.toDate() }
        }
        .presentationDetents([.medium])
    }

    private var dayPickerSheet: some View {
        NavigationStack {
            List(DayOfWeek.allCases, id: \.self) { day in
                Button {
                    viewModel.setDigestDay(day)
                    showDigestDayPicker = false
                } label: {
                    HStack {
                        Text(day.displayName)
                        Spacer()
                        if viewModel.settings.digestDay == day {
                            Image(systemName: "checkmark")
                                .foregroundStyle(DS.Colors.accent)
                        }
                    }
                }
            }
            .navigationTitle("Digest Day")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { showDigestDayPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func dismissSheets() {
        showBreachTimePicker = false
        showDigestTimePicker = false
    }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}
