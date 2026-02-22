//
//  SettingsView.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel = SettingsViewModel()

    @State private var showBreachTimePicker = false
    @State private var showDigestTimePicker = false
    @State private var showDigestDayPicker = false
    @State private var shareItem: ShareItem?
    @State private var workingTime = Date()
    @State private var showNoNewContactsAlert = false
    @State private var showNewContactsPicker = false
    @State private var showGroupAssignment = false
    @State private var shouldShowGroupAssignment = false
    @State private var selectedForImport: [ContactSummary] = []
    @State private var pendingImportCount = 0
    @State private var isSyncingContacts = false

    var body: some View {
        List {
            appearanceSection
            groupsSection
            tagsSection
            notificationsSection
            dataSection
            pausedSection
            advancedSection
            aboutSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
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
                    Task {
                        isSyncingContacts = true
                        await viewModel.importSelectedContacts(selectedForImport, groupAssignments: assignments)
                        isSyncingContacts = false
                    }
                    showGroupAssignment = false
                },
                onCancel: {
                    showGroupAssignment = false
                }
            )
        }
        .onChange(of: showNewContactsPicker) { _, isPresented in
            if !isPresented && shouldShowGroupAssignment {
                shouldShowGroupAssignment = false
                showGroupAssignment = true
            }
        }
        .onAppear { viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .personDidChange)) { _ in
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

    private var groupsSection: some View {
        Section("Contact Frequency") {
            NavigationLink {
                ManageGroupsView()
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(DS.Colors.accent)
                    Text("Manage Frequencies")
                    Spacer()
                    Text("\(viewModel.groupsCount)")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var tagsSection: some View {
        Section("Groups") {
            NavigationLink {
                ManageTagsView()
            } label: {
                HStack {
                    Image(systemName: "person.3.fill")
                        .foregroundStyle(DS.Colors.accent)
                    Text("Manage Groups")
                    Spacer()
                    Text("\(viewModel.tagsCount)")
                        .foregroundStyle(.secondary)
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

            Toggle(isOn: Binding(
                get: { viewModel.settings.digestEnabled },
                set: { newValue in viewModel.setDigestEnabled(newValue) }
            )) {
                Label("Weekly Digest", systemImage: "bell.badge.fill")
                    .foregroundStyle(DS.Colors.accent)
            }

            if viewModel.settings.notificationsEnabled {
                Button {
                    showBreachTimePicker = true
                } label: {
                    HStack {
                        Text("Reminder Time")
                        Spacer()
                        Text(viewModel.settings.breachTimeOfDay.formatted)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if viewModel.settings.digestEnabled {
                Button {
                    showDigestDayPicker = true
                } label: {
                    HStack {
                        Text("Digest Day")
                        Spacer()
                        Text(viewModel.settings.digestDay.displayName)
                            .foregroundStyle(.secondary)
                    }
                }
                Button {
                    showDigestTimePicker = true
                } label: {
                    HStack {
                        Text("Digest Time")
                        Spacer()
                        Text(viewModel.settings.digestTime.formatted)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Picker("Reminder Grouping", selection: Binding(
                get: { viewModel.settings.notificationGrouping },
                set: { viewModel.setNotificationGrouping($0) }
            )) {
                ForEach(NotificationGrouping.allCases, id: \.self) { option in
                    Text(option.displayName).tag(option)
                }
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
                Task {
                    isSyncingContacts = true
                    let started = Date()
                    let count = await viewModel.findNewContacts()
                    pendingImportCount = count
                    let elapsed = Date().timeIntervalSince(started)
                    if elapsed < 0.6 {
                        try? await Task.sleep(nanoseconds: UInt64((0.6 - elapsed) * 1_000_000_000))
                    }
                    isSyncingContacts = false
                    if count > 0 {
                        showNewContactsPicker = true
                    } else {
                        showNoNewContactsAlert = true
                    }
                }
            } label: {
                Label("Add from Contacts", systemImage: "arrow.triangle.2.circlepath")
            }

            if let lastSync = viewModel.settings.lastContactsSyncAt {
                Text("Last sync: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                    .font(DS.Typography.metadata)
                    .foregroundStyle(DS.Colors.secondaryText)
            }

            if isSyncingContacts {
                HStack(spacing: DS.Spacing.md) {
                    ProgressView()
                    Text("Checking contacts...")
                        .font(DS.Typography.metadata)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
            }
        }
    }

    private var pausedSection: some View {
        Section("Paused Contacts") {
            NavigationLink {
                PausedContactsView()
            } label: {
                HStack {
                    Image(systemName: "pause.circle.fill")
                        .foregroundStyle(DS.Colors.secondaryText)
                    Text("Paused Contacts")
                    Spacer()
                    Text("\(viewModel.pausedCount)")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var advancedSection: some View {
        Section("Advanced") {
            NavigationLink(destination: AdvancedSettingsView(viewModel: viewModel)) {
                Label("Advanced Settings", systemImage: "gearshape.2")
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
            VStack(spacing: DS.Spacing.sm) {
                Text("Stay in Touch \(appVersion)")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
                Text("Privacy-first personal CRM")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.sm)
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
