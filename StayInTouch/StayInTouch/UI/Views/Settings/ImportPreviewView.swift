//
//  ImportPreviewView.swift
//  KeepInTouch
//
//  Created by Claude on 2/27/26.
//

import SwiftUI

struct ImportPreviewView: View {
    let preview: ImportPreview
    let onImport: (ImportPreview) -> Void
    let onCancel: () -> Void

    /// User's disambiguation choices: export person UUID → chosen tracked Person UUID
    @State private var disambiguationChoices: [UUID: UUID] = [:]

    private var allDisambiguated: Bool {
        preview.ambiguousPeople.allSatisfy { disambiguationChoices[$0.export.id] != nil }
    }

    private var resolvedPreview: ImportPreview {
        var resolved = preview
        for (exportPerson, _) in preview.ambiguousPeople {
            if let chosenId = disambiguationChoices[exportPerson.id] {
                resolved.remappedIds[exportPerson.id] = chosenId
            }
        }
        return resolved
    }

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
                    Section("Matched Contacts (\(preview.updatedPeople.count))") {
                        ForEach(preview.updatedPeople, id: \.id) { person in
                            Label(person.displayName, systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                }

                if !preview.ambiguousPeople.isEmpty {
                    disambiguationSection
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
                    Button("Import") { onImport(resolvedPreview) }
                        .bold()
                        .disabled(preview.isEmpty || !allDisambiguated)
                }
            }
        }
    }

    // MARK: - Summary

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
            if !preview.ambiguousPeople.isEmpty {
                Label("\(preview.ambiguousPeople.count) contact\(preview.ambiguousPeople.count == 1 ? "" : "s") need\(preview.ambiguousPeople.count == 1 ? "s" : "") your selection", systemImage: "questionmark.circle.fill")
                    .foregroundStyle(DS.Colors.statusDueSoon)
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
                if preview.newTouchEventCount == preview.touchEventCount {
                    Label("\(preview.touchEventCount) activit\(preview.touchEventCount == 1 ? "y" : "ies") will be imported", systemImage: "hand.tap.fill")
                        .foregroundStyle(DS.Colors.statusDueSoon)
                } else if preview.newTouchEventCount > 0 {
                    let existing = preview.touchEventCount - preview.newTouchEventCount
                    Label("\(preview.newTouchEventCount) new activit\(preview.newTouchEventCount == 1 ? "y" : "ies") will be imported (\(existing) already exist)", systemImage: "hand.tap.fill")
                        .foregroundStyle(DS.Colors.statusDueSoon)
                } else {
                    Label("All \(preview.touchEventCount) activit\(preview.touchEventCount == 1 ? "y" : "ies") already imported", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(DS.Colors.secondaryText)
                }
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

    // MARK: - Disambiguation Helpers

    private var disambiguationSection: some View {
        let items = preview.ambiguousPeople.map {
            AmbiguousItem(exportPerson: $0.export, candidates: $0.candidates)
        }
        return Section("Select Matching Contact") {
            Text("The following imported contacts match multiple people you're tracking. Select which contact to update for each.")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondaryText)

            ForEach(items) { item in
                disambiguationRow(item: item)
            }
        }
    }

    private func disambiguationRow(item: AmbiguousItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.exportPerson.displayName)
                .font(DS.Typography.contactName)

            Menu {
                ForEach(item.candidates, id: \.id) { candidate in
                    Button(candidateLabel(candidate)) {
                        disambiguationChoices[item.exportPerson.id] = candidate.id
                    }
                }
            } label: {
                HStack {
                    if let chosenId = disambiguationChoices[item.exportPerson.id],
                       let chosen = item.candidates.first(where: { $0.id == chosenId }) {
                        Text(candidateLabel(chosen))
                            .foregroundStyle(DS.Colors.primaryText)
                    } else {
                        Text("Select a contact...")
                            .foregroundStyle(DS.Colors.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func candidateLabel(_ person: Person) -> String {
        var parts = [person.displayName]
        if let method = person.lastTouchMethod {
            parts.append("Last: \(method.rawValue)")
        }
        return parts.joined(separator: " \u{2022} ")
    }
}

private struct AmbiguousItem: Identifiable {
    let exportPerson: ExportPerson
    let candidates: [Person]
    var id: UUID { exportPerson.id }
}
