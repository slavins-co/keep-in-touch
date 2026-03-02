//
//  PostImportMatchView.swift
//  StayInTouch
//
//  Created by Claude on 3/2/26.
//

import SwiftUI

struct PostImportMatchView: View {
    let importResult: ImportResult
    let initialMatchSummary: ContactMatchSummary
    @ObservedObject var viewModel: SettingsViewModel
    let onDismiss: () -> Void

    @State private var linkedNames: [String]
    @State private var unmatchedPeople: [(id: UUID, displayName: String)]
    @State private var linkingPersonId: UUID?

    init(importResult: ImportResult, matchSummary: ContactMatchSummary, viewModel: SettingsViewModel, onDismiss: @escaping () -> Void) {
        self.importResult = importResult
        self.initialMatchSummary = matchSummary
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        _linkedNames = State(initialValue: matchSummary.matchedNames)
        _unmatchedPeople = State(initialValue: matchSummary.unmatchedPeople)
    }

    var body: some View {
        NavigationStack {
            List {
                summarySection
                importSummarySection

                if !linkedNames.isEmpty {
                    Section("Linked to Address Book (\(linkedNames.count))") {
                        ForEach(linkedNames, id: \.self) { name in
                            Label(name, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(DS.Colors.statusAllGood)
                        }
                    }
                }

                if !unmatchedPeople.isEmpty {
                    Section("Not Linked (\(unmatchedPeople.count))") {
                        ForEach(unmatchedPeople, id: \.id) { person in
                            HStack {
                                Label(person.displayName, systemImage: "person.crop.circle.badge.questionmark")
                                Spacer()
                                Button("Link") {
                                    linkingPersonId = person.id
                                    ContactPickerPresenter.present { cnIdentifier in
                                        if let personId = linkingPersonId {
                                            viewModel.linkContactManually(personId: personId, cnIdentifier: cnIdentifier)
                                            if let index = unmatchedPeople.firstIndex(where: { $0.id == personId }) {
                                                let name = unmatchedPeople[index].displayName
                                                unmatchedPeople.remove(at: index)
                                                linkedNames.append(name)
                                            }
                                        }
                                        linkingPersonId = nil
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Import Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                        .bold()
                }
            }
        }
    }

    private var summarySection: some View {
        Section {
            if linkedNames.isEmpty && unmatchedPeople.isEmpty {
                Label("No contacts to link to your address book", systemImage: "info.circle")
                    .foregroundStyle(DS.Colors.secondaryText)
            } else {
                let total = linkedNames.count + unmatchedPeople.count
                Label("\(linkedNames.count) of \(total) contact\(total == 1 ? "" : "s") linked to your address book", systemImage: "person.crop.circle.badge.checkmark")
                    .foregroundStyle(linkedNames.isEmpty ? DS.Colors.secondaryText : DS.Colors.statusAllGood)
            }
        }
    }

    private var importSummarySection: some View {
        Section("Imported") {
            if importResult.totalPeople > 0 {
                Label("\(importResult.totalPeople) contact\(importResult.totalPeople == 1 ? "" : "s")", systemImage: "person.fill")
            }
            if importResult.groupsCreated > 0 {
                Label("\(importResult.groupsCreated) frequenc\(importResult.groupsCreated == 1 ? "y" : "ies")", systemImage: "clock.badge.checkmark.fill")
            }
            if importResult.tagsCreated > 0 {
                Label("\(importResult.tagsCreated) group\(importResult.tagsCreated == 1 ? "" : "s")", systemImage: "person.3.fill")
            }
        }
    }
}
