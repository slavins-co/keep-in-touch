//
//  GroupEditorSheet.swift
//  StayInTouch
//
//  Created by Codex on 2/3/26.
//

import SwiftUI

struct GroupEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let group: Group?
    let existingNames: [String]
    let onSave: (Group, Bool) -> Void
    let onCancel: () -> Void
    let defaultSortOrder: Int

    @State private var name: String
    @State private var slaDays: Int
    @State private var warningDays: Int
    @State private var isDefault: Bool

    init(group: Group?, existingNames: [String], defaultSortOrder: Int, onSave: @escaping (Group, Bool) -> Void, onCancel: @escaping () -> Void) {
        self.group = group
        self.existingNames = existingNames
        self.defaultSortOrder = defaultSortOrder
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: group?.name ?? "")
        _slaDays = State(initialValue: group?.slaDays ?? 30)
        _warningDays = State(initialValue: group?.warningDays ?? 3)
        _isDefault = State(initialValue: group?.isDefault ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Group Name") {
                    TextField("Close Friends", text: $name)
                }

                Section("Check-in Interval (Days)") {
                    Stepper(value: $slaDays, in: 1...365) {
                        Text("\(slaDays) days")
                    }
                }

                Section("Warning Days Before Due") {
                    Stepper(value: $warningDays, in: 0...max(0, slaDays - 1)) {
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
            .navigationTitle(group == nil ? "New Group" : "Edit Group")
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
        if let group {
            if trimmed.caseInsensitiveCompare(group.name) != .orderedSame {
                if existingNames.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                    return false
                }
            }
        } else if existingNames.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return false
        }
        return slaDays >= 1 && slaDays <= 365 && warningDays < slaDays
    }

    private func handleSave() {
        let now = Date()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let saved = Group(
            id: group?.id ?? UUID(),
            name: trimmed,
            slaDays: slaDays,
            warningDays: warningDays,
            colorHex: group?.colorHex,
            isDefault: group?.isDefault ?? false,
            sortOrder: group?.sortOrder ?? defaultSortOrder,
            createdAt: group?.createdAt ?? now,
            modifiedAt: now
        )
        onSave(saved, isDefault)
        dismiss()
    }
}
