//
//  GroupEditorSheet.swift
//  KeepInTouch
//
//  Created by Codex on 2/3/26.
//

import SwiftUI

struct GroupEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let group: Group?
    let existingNames: [String]
    let onSave: (Group) -> Void
    let onCancel: () -> Void
    let defaultSortOrder: Int

    @State private var name: String
    @State private var color: Color

    init(group: Group?, existingNames: [String], defaultSortOrder: Int, onSave: @escaping (Group) -> Void, onCancel: @escaping () -> Void) {
        self.group = group
        self.existingNames = existingNames
        self.defaultSortOrder = defaultSortOrder
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: group?.name ?? "")
        _color = State(initialValue: group.map { Color(hex: $0.colorHex) } ?? .blue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Group Name") {
                    TextField("Colleague", text: $name)
                }

                Section("Color") {
                    ColorPicker("", selection: $color, supportsOpacity: false)
                        .labelsHidden()
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
        return true
    }

    private func handleSave() {
        let now = Date()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let saved = Group(
            id: group?.id ?? UUID(),
            name: trimmed,
            colorHex: color.toHex(),
            sortOrder: group?.sortOrder ?? defaultSortOrder,
            createdAt: group?.createdAt ?? now,
            modifiedAt: now
        )
        onSave(saved)
        dismiss()
    }
}
