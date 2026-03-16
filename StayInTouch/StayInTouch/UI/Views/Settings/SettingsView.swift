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

    @State private var shareItem: ShareItem?
    @State private var showNoNewContactsAlert = false
    @State private var showLimitedAccessAlert = false
    @State private var showContactsSettingsAlert = false
    @State private var contactImportStep: ContactImportStep?
    @State private var pendingImportStep: ContactImportStep?
    @State private var showImportSuccessBanner = false
    @State private var importSuccessCount = 0
    @State private var importBannerTask: Task<Void, Never>?
    @State private var showFilePicker = false
    @State private var importPreview: ImportPreview?
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
        .overlay(alignment: .top) {
            if showImportSuccessBanner {
                importSuccessBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showImportSuccessBanner)
        .listStyle(.insetGrouped)
        .tint(DS.Colors.accent)
        .navigationTitle("Settings")
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url]) {
                try? FileManager.default.removeItem(at: item.url)
            }
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
        .sheet(item: $contactImportStep, onDismiss: {
            if let next = pendingImportStep {
                pendingImportStep = nil
                contactImportStep = next
            } else if importSuccessCount > 0 {
                showImportSuccessBanner = true
                importBannerTask?.cancel()
                importBannerTask = Task {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    guard !Task.isCancelled else { return }
                    showImportSuccessBanner = false
                    importSuccessCount = 0
                }
            }
        }) { step in
            switch step {
            case .pickingContacts:
                NewContactsPickerView(
                    contacts: viewModel.pendingNewContacts,
                    onImport: { selected in
                        pendingImportStep = .assigningGroups(selected: selected)
                        contactImportStep = nil
                    },
                    onCancel: {
                        viewModel.pendingNewContacts = []
                        pendingImportStep = nil
                        contactImportStep = nil
                    }
                )
            case .assigningGroups(let selected):
                SettingsCadenceAssignmentView(
                    contacts: selected,
                    groups: viewModel.allGroups,
                    onImport: { assignments in
                        pendingImportStep = .seedingLastTouch(selected: selected, assignments: assignments)
                        contactImportStep = nil
                    },
                    onCancel: {
                        pendingImportStep = nil
                        contactImportStep = nil
                    }
                )
            case .seedingLastTouch(let selected, let assignments):
                SettingsLastTouchSeedingView(
                    contacts: selected,
                    onContinue: { lastTouchSelections in
                        importSuccessCount = selected.count
                        Task {
                            await viewModel.importSelectedContacts(
                                selected,
                                groupAssignments: assignments,
                                lastTouchSelections: lastTouchSelections
                            )
                        }
                        contactImportStep = nil
                    },
                    onCancel: {
                        pendingImportStep = nil
                        contactImportStep = nil
                    }
                )
            }
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [UTType.json]) { result in
            switch result {
            case .success(let url):
                Task {
                    if let preview = await viewModel.parseImportFile(url: url) {
                        importPreview = preview
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
        .sheet(item: $importPreview) { preview in
            ImportPreviewView(
                preview: preview,
                onImport: { resolvedPreview in
                    importPreview = nil
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
                    importPreview = nil
                }
            )
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
                ManageCadencesView()
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
                        contactImportStep = .pickingContacts
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
            NavigationLink(destination: NotificationSettingsView(viewModel: viewModel)) {
                Label("Notifications", systemImage: "bell.fill")
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

            if viewModel.isImporting {
                HStack(spacing: DS.Spacing.md) {
                    ProgressView()
                    Text("Importing...")
                        .font(DS.Typography.metadata)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
            }
        }
    }

    private var appVersion: String {
        "v\(GeneratedVersion.marketing) (\(GeneratedVersion.build))"
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

    // MARK: - Import Success Banner

    private var importSuccessBanner: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.white)
            Text("Imported \(importSuccessCount) contact\(importSuccessCount == 1 ? "" : "s")")
                .font(DS.Typography.metadata)
                .foregroundStyle(.white)
            Spacer()
            Button {
                importBannerTask?.cancel()
                showImportSuccessBanner = false
                importSuccessCount = 0
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.statusAllGood)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.top, DS.Spacing.sm)
    }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private enum ContactImportStep: Identifiable {
    case pickingContacts
    case assigningGroups(selected: [ContactSummary])
    case seedingLastTouch(selected: [ContactSummary], assignments: [String: UUID])

    var id: String {
        switch self {
        case .pickingContacts: return "picking"
        case .assigningGroups: return "groups"
        case .seedingLastTouch: return "seeding"
        }
    }
}
