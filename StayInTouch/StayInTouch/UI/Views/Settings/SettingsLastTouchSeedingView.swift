//
//  SettingsLastTouchSeedingView.swift
//  KeepInTouch
//

import SwiftUI

struct SettingsLastTouchSeedingView: View {
    let contacts: [ContactSummary]
    let onContinue: ([String: LastTouchOption]) -> Void
    let onCancel: () -> Void

    @State private var selections: [String: LastTouchOption] = [:]

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.md) {
                Text("Set an approximate date for each person.")
                    .font(DS.Typography.metadata)
                    .foregroundStyle(DS.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, DS.Spacing.sm)

                List(contacts) { contact in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(contact.displayName)
                            .font(DS.Typography.contactName)

                        Picker("Last connected", selection: binding(for: contact.identifier)) {
                            ForEach(LastTouchOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(.vertical, DS.Spacing.sm)
                }
                .listStyle(.plain)
            }
            .navigationTitle("Last Connected")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Import") { onContinue(selections) }
                }
            }
            .onAppear {
                for contact in contacts where selections[contact.identifier] == nil {
                    selections[contact.identifier] = .cantRemember
                }
            }
        }
    }

    private func binding(for contactId: String) -> Binding<LastTouchOption> {
        Binding<LastTouchOption>(
            get: { selections[contactId] ?? .cantRemember },
            set: { selections[contactId] = $0 }
        )
    }
}
