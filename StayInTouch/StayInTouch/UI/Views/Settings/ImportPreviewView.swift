//
//  ImportPreviewView.swift
//  StayInTouch
//
//  Created by Claude on 2/27/26.
//

import SwiftUI

struct ImportPreviewView: View {
    let preview: ImportPreview
    let onImport: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List {
                summarySection

                if !preview.newGroups.isEmpty {
                    Section("New Frequencies (\(preview.newGroups.count))") {
                        ForEach(preview.newGroups, id: \.id) { group in
                            Label {
                                HStack {
                                    Text(group.name)
                                    Spacer()
                                    Text("Every \(group.frequencyDays) days")
                                        .font(DS.Typography.caption)
                                        .foregroundStyle(DS.Colors.secondaryText)
                                }
                            } icon: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                        }
                    }
                }

                if !preview.newTags.isEmpty {
                    Section("New Groups (\(preview.newTags.count))") {
                        ForEach(preview.newTags, id: \.id) { tag in
                            Label(tag.name, systemImage: "person.3")
                        }
                    }
                }

                if !preview.newPeople.isEmpty {
                    Section("New Contacts (\(preview.newPeople.count))") {
                        ForEach(preview.newPeople, id: \.id) { person in
                            Label(person.displayName, systemImage: "person.badge.plus")
                        }
                    }
                }

                if !preview.updatedPeople.isEmpty {
                    Section("Existing Contacts (\(preview.updatedPeople.count))") {
                        ForEach(preview.updatedPeople, id: \.id) { person in
                            Label(person.displayName, systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Import Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import", action: onImport)
                        .bold()
                        .disabled(preview.isEmpty)
                }
            }
        }
    }

    private var summarySection: some View {
        Section {
            if !preview.newPeople.isEmpty {
                Label("\(preview.newPeople.count) new contact\(preview.newPeople.count == 1 ? "" : "s") will be added", systemImage: "plus.circle.fill")
                    .foregroundStyle(DS.Colors.statusAllGood)
            }
            if !preview.updatedPeople.isEmpty {
                Label("\(preview.updatedPeople.count) existing contact\(preview.updatedPeople.count == 1 ? "" : "s") will be updated", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                    .foregroundStyle(DS.Colors.accent)
            }
            if !preview.newGroups.isEmpty {
                Label("\(preview.newGroups.count) new frequenc\(preview.newGroups.count == 1 ? "y" : "ies") will be created", systemImage: "clock.badge.checkmark.fill")
                    .foregroundStyle(DS.Colors.accent)
            }
            if !preview.newTags.isEmpty {
                Label("\(preview.newTags.count) new group\(preview.newTags.count == 1 ? "" : "s") will be created", systemImage: "person.3.fill")
                    .foregroundStyle(DS.Colors.accent)
            }
            if preview.touchEventCount > 0 {
                Label("\(preview.touchEventCount) touch event\(preview.touchEventCount == 1 ? "" : "s") will be imported", systemImage: "hand.tap.fill")
                    .foregroundStyle(DS.Colors.statusDueSoon)
            }
            if preview.skippedCount > 0 {
                Label("\(preview.skippedCount) invalid entr\(preview.skippedCount == 1 ? "y" : "ies") will be skipped", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(DS.Colors.statusOverdue)
            }
            if preview.isEmpty {
                Label("Nothing to import", systemImage: "info.circle")
                    .foregroundStyle(DS.Colors.secondaryText)
            }
        }
    }
}
