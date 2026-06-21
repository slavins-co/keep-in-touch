//
//  SettingsView.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject private var purchaseManager: PurchaseManager

    @State private var paywallTrigger: PaywallTrigger?
    @State private var showNoNewContactsAlert = false
    @State private var showLimitedAccessAlert = false
    @State private var showContactsSettingsAlert = false
    @State private var contactImportStep: ContactImportStep?
    @State private var pendingImportStep: ContactImportStep?
    @State private var showImportSuccessBanner = false
    @State private var importSuccessCount = 0
    @State private var importBannerTask: Task<Void, Never>?
    @State private var showResetFrequenciesConfirmation = false
    @State private var showResetTipsConfirm = false

    var body: some View {
        List {
            proSection
            appearanceSection
            peopleSection
            notificationsSection
            insightsSection
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
        .contactAccessAlerts(
            showNoNewContacts: $showNoNewContactsAlert,
            showLimitedAccess: $showLimitedAccessAlert,
            showContactsSettings: $showContactsSettingsAlert
        )
        .alert("Reset Feature Tips?", isPresented: $showResetTipsConfirm) {
            Button("Reset", role: .destructive) { viewModel.resetFeatureTips() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Feature tips will reset the next time you open Keep In Touch.")
        }
        .sheet(item: $contactImportStep, onDismiss: {
            if let next = pendingImportStep {
                pendingImportStep = nil
                contactImportStep = next
            } else if importSuccessCount > 0 {
                showImportSuccessBanner = true
                importBannerTask?.cancel()
                importBannerTask = Task {
                    try? await Task.sleep(nanoseconds: DS.nanoseconds(DS.Timing.undoBannerSeconds))
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
                    currentTrackedCount: { viewModel.liveTrackedCount() },
                    capSource: "settings",
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
                .environmentObject(purchaseManager)
            case .assigningGroups(let selected):
                SettingsCadenceAssignmentView(
                    contacts: selected,
                    cadences: viewModel.allCadences,
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
        .sheet(item: $paywallTrigger) { trigger in
            PaywallView(source: trigger.source)
                .environmentObject(purchaseManager)
        }
        .onAppear { viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .personDidChange)) { _ in
            viewModel.load()
        }
    }

    private var proSection: some View {
        Section {
            if purchaseManager.isPro {
                HStack {
                    Label("Keep In Touch Pro", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(DS.Colors.accent)
                    Spacer()
                    Text("Active")
                        .font(DS.Typography.metadata)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
            } else {
                Button {
                    paywallTrigger = PaywallTrigger(source: "settings_upgrade")
                } label: {
                    Label("Unlock Keep In Touch Pro", systemImage: "star.circle.fill")
                }
            }

            Button {
                Task { await purchaseManager.restore() }
            } label: {
                Label("Restore Purchases", systemImage: "arrow.clockwise")
            }
            .accessibilityHint("Restores a previous Pro purchase")
        } header: {
            if !purchaseManager.isPro {
                Text("Upgrade")
            }
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
                    Text("\(viewModel.cadencesCount)")
                        .foregroundStyle(DS.Colors.secondaryText)
                }
            }

            NavigationLink {
                ManageGroupsView()
            } label: {
                HStack {
                    Image(systemName: "person.3.fill")
                        .foregroundStyle(DS.Colors.accent)
                    Text("Manage Groups")
                    Spacer()
                    Text("\(viewModel.groupsCount)")
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

            NavigationLink {
                SnoozedContactsView()
            } label: {
                HStack {
                    Image(systemName: "moon.zzz.fill")
                        .foregroundStyle(DS.Colors.secondaryText)
                    Text("Snoozed Contacts")
                    Spacer()
                    Text("\(viewModel.snoozedCount)")
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

    private var insightsSection: some View {
        Section("Insights") {
            if purchaseManager.isPro {
                NavigationLink {
                    StatsView(viewModel: StatsViewModel())
                } label: {
                    Label("Stats & insights", systemImage: "chart.bar")
                }
            } else {
                Button {
                    AnalyticsService.track("pro.gate_tapped", parameters: ["source": "stats"])
                    paywallTrigger = PaywallTrigger(source: "stats")
                } label: {
                    HStack {
                        Label("Stats & insights", systemImage: "chart.bar")
                        Spacer()
                        Image(systemName: "lock.fill")
                            .foregroundStyle(DS.Colors.secondaryText)
                    }
                }
            }
        }
    }

    private var dataSection: some View {
        Section("Data") {
            NavigationLink(destination: DataSettingsView(viewModel: viewModel)) {
                Label("Backup & Data", systemImage: "externaldrive.badge.icloud")
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

            Button {
                viewModel.replayTutorial()
            } label: {
                Label("Replay Tutorial", systemImage: "sparkles")
            }
            .accessibilityHint("Re-runs the welcome walkthrough on Home")

            Button {
                showResetTipsConfirm = true
            } label: {
                Label("Reset Feature Tips", systemImage: "lightbulb")
            }
            .accessibilityHint("Makes all hint popovers eligible again")

            NavigationLink(destination: AdvancedSettingsView(viewModel: viewModel)) {
                Label("Advanced Settings", systemImage: "gearshape.2")
            }
        } header: {
            Text("About")
        } footer: {
            VStack(spacing: DS.Spacing.md) {
                Text("Your relationship data lives on your device and is never sent to us. Anonymous usage statistics help us improve the app.")
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
