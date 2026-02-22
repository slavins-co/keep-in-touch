//
//  SettingsGroupAssignmentView.swift
//  StayInTouch
//
//  Created by Codex on 2/15/26.
//

import SwiftUI

struct SettingsGroupAssignmentView: View {
    let contacts: [ContactSummary]
    let groups: [Group]
    let onImport: ([String: UUID]) -> Void
    let onCancel: () -> Void

    @State private var assignments: [String: UUID] = [:]

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.md) {
                Text("Assign Groups")
                    .font(DS.Typography.title)
                    .padding(.top)

                Text("Pick how often you want to stay in touch with each person.")
                    .font(DS.Typography.metadata)
                    .foregroundStyle(DS.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                List(contacts) { contact in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(contact.displayName)
                            .font(DS.Typography.contactName)

                        Picker("Group", selection: binding(for: contact.identifier)) {
                            ForEach(groups, id: \.id) { group in
                                Text(group.name).tag(group.id)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(.vertical, DS.Spacing.sm)
                }
                .listStyle(.plain)
            }
            .navigationTitle("Assign Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Import") { onImport(assignments) }
                }
            }
            .onAppear {
                let defaultId = groups.first(where: { $0.isDefault })?.id ?? groups.first?.id ?? UUID()
                for contact in contacts where assignments[contact.identifier] == nil {
                    assignments[contact.identifier] = defaultId
                }
            }
        }
    }

    private func binding(for contactId: String) -> Binding<UUID> {
        let fallback = groups.first(where: { $0.isDefault })?.id ?? groups.first?.id ?? UUID()
        return Binding<UUID>(
            get: { assignments[contactId] ?? fallback },
            set: { assignments[contactId] = $0 }
        )
    }
}
