//
//  CadenceEditorSheet.swift
//  KeepInTouch
//
//  Created by Codex on 2/3/26.
//

import SwiftUI

struct CadenceEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let cadence: Cadence?
    let existingNames: [String]
    let onSave: (Cadence, Bool) -> Void
    let onCancel: () -> Void
    let defaultSortOrder: Int

    @State private var name: String
    @State private var frequencyDays: Int
    @State private var warningDays: Int
    @State private var isDefault: Bool

    init(cadence: Cadence?, existingNames: [String], defaultSortOrder: Int, onSave: @escaping (Cadence, Bool) -> Void, onCancel: @escaping () -> Void) {
        self.cadence = cadence
        self.existingNames = existingNames
        self.defaultSortOrder = defaultSortOrder
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: cadence?.name ?? "")
        _frequencyDays = State(initialValue: cadence?.frequencyDays ?? 30)
        _warningDays = State(initialValue: cadence?.warningDays ?? 3)
        _isDefault = State(initialValue: cadence?.isDefault ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Frequency Name") {
                    TextField("Close Friends", text: $name)
                }

                Section("Check-in Interval (Days)") {
                    Stepper(value: $frequencyDays, in: 1...365) {
                        Text("\(frequencyDays) days")
                    }
                }

                Section("Warning Days Before Due") {
                    Stepper(value: $warningDays, in: 0...max(0, frequencyDays - 1)) {
                        Text("\(warningDays) days")
                    }
                    Text("Show \"due soon\" before the interval expires")
                        .font(DS.Typography.metadata)
                        .foregroundStyle(DS.Colors.secondaryText)
                }

                Section {
                    Toggle("Set as default", isOn: $isDefault)
                }
            }
            .navigationTitle(cadence == nil ? "New Frequency" : "Edit Frequency")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { handleSave() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 50 else { return false }
        if let cadence {
            if trimmed.caseInsensitiveCompare(cadence.name) != .orderedSame {
                if existingNames.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                    return false
                }
            }
        } else if existingNames.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return false
        }
        return frequencyDays >= 1 && frequencyDays <= 365 && warningDays < frequencyDays
    }

    private func handleSave() {
        let now = Date()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let saved = Cadence(
            id: cadence?.id ?? UUID(),
            name: trimmed,
            frequencyDays: frequencyDays,
            warningDays: warningDays,
            colorHex: cadence?.colorHex,
            isDefault: cadence?.isDefault ?? false,
            sortOrder: cadence?.sortOrder ?? defaultSortOrder,
            createdAt: cadence?.createdAt ?? now,
            modifiedAt: now
        )
        onSave(saved, isDefault)
        dismiss()
    }
}
