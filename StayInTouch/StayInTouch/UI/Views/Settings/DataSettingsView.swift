//
//  DataSettingsView.swift
//  KeepInTouch
//
//  Backup reassurance + data export/import, extracted from SettingsView.
//

import SwiftUI
import UniformTypeIdentifiers

struct DataSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @EnvironmentObject private var purchaseManager: PurchaseManager

    @State private var paywallTrigger: PaywallTrigger?
    @State private var shareItem: ShareItem?
    @State private var showFilePicker = false
    @State private var importPreview: ImportPreview?
    @State private var showImportSuccessAlert = false
    @State private var showImportErrorAlert = false
    @State private var importResultMessage = ""
    @State private var showExportFormatPicker = false
    @State private var showPostImportMatch = false
    @State private var postImportResult: ImportResult?
    @State private var postImportMatchSummary: ContactMatchSummary?

    var body: some View {
        List {
            backupSection
            exportImportSection
            privacySection
        }
        .listStyle(.insetGrouped)
        .tint(DS.Colors.accent)
        .navigationTitle("Data & Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareItem) { item in
            ShareSheet(items: item.urls) {
                for url in item.urls {
                    try? FileManager.default.removeItem(at: url)
                }
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
                            if result.cadencesCreated > 0 {
                                parts.append("\(result.cadencesCreated) frequenc\(result.cadencesCreated == 1 ? "y" : "ies")")
                            }
                            if result.groupsCreated > 0 {
                                parts.append("\(result.groupsCreated) group\(result.groupsCreated == 1 ? "" : "s")")
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
        .sheet(item: $paywallTrigger) { trigger in
            PaywallView(source: trigger.source)
                .environmentObject(purchaseManager)
        }
    }

    // MARK: - Backup

    private var backupSection: some View {
        Section {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "externaldrive.fill")
                    .font(.title3)
                    .foregroundStyle(DS.Colors.statusAllGood)
                Text("Your data is backed up with your device")
                    .font(DS.Typography.settingsRowLabel)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Your data is backed up with your device")
            .accessibilityHint("Your relationship data is restored automatically when you set up a new iPhone from an iCloud backup")
        } header: {
            Text("Backup")
        } footer: {
            Text("Keep In Touch stores everything on your device, and your relationship data is never sent to us. When iCloud Backup is turned on in iOS Settings, this app's data is included in your device's encrypted backup and restores automatically on a new iPhone. For a portable copy you control, use Export below to save a file to Files or iCloud Drive.")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondaryText)
        }
    }

    // MARK: - Export & Import

    private var exportImportSection: some View {
        Section {
            Button {
                showExportFormatPicker = true
            } label: {
                Label("Export Contacts", systemImage: "square.and.arrow.up")
            }
            .confirmationDialog("Export Format", isPresented: $showExportFormatPicker) {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    Button(format.displayName) {
                        let urls = viewModel.exportContacts(format: format)
                        if !urls.isEmpty {
                            shareItem = ShareItem(urls: urls)
                        }
                    }
                }
            } message: {
                Text("Choose a format for your export.")
            }

            Button {
                if purchaseManager.isPro {
                    showFilePicker = true
                } else {
                    AnalyticsService.track("pro.gate_tapped", parameters: ["source": "import"])
                    paywallTrigger = PaywallTrigger(source: "import")
                }
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
        } header: {
            Text("Export & Import")
        }
    }

    // MARK: - Privacy

    /// Hosted privacy policy (GitHub Pages from `main/docs`; same URL set in
    /// App Store Connect). A hardcoded, known-valid literal — safe to unwrap.
    private static let privacyPolicyURL = URL(string: "https://slavins-co.github.io/keep-in-touch/privacy-policy")!

    private var privacySection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { viewModel.settings.analyticsEnabled },
                set: { viewModel.setAnalyticsEnabled($0) }
            )) {
                Label("Anonymous Usage Analytics", systemImage: "shield.checkered")
            }

            Link(destination: Self.privacyPolicyURL) {
                Label("Privacy Policy", systemImage: "hand.raised.fill")
            }
        } header: {
            Text("Privacy")
        } footer: {
            Text("Your relationship data lives on your device and is never sent to us. Anonymous usage statistics (no names, no contact data) help improve the app — turn them off anytime.")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondaryText)
        }
    }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let urls: [URL]
}
