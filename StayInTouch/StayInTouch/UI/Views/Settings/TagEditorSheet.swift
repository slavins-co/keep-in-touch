//
//  TagEditorSheet.swift
//  StayInTouch
//
//  Created by Codex on 2/3/26.
//

import SwiftUI

struct TagEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let tag: Tag?
    let existingNames: [String]
    let onSave: (Tag) -> Void
    let onCancel: () -> Void
    let defaultSortOrder: Int

    @State private var name: String
    @State private var color: Color

    init(tag: Tag?, existingNames: [String], defaultSortOrder: Int, onSave: @escaping (Tag) -> Void, onCancel: @escaping () -> Void) {
        self.tag = tag
        self.existingNames = existingNames
        self.defaultSortOrder = defaultSortOrder
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: tag?.name ?? "")
        _color = State(initialValue: tag.map { Color(hex: $0.colorHex) } ?? .blue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tag Name") {
                    TextField("Colleague", text: $name)
                }

                Section("Color") {
                    ColorPicker("", selection: $color, supportsOpacity: false)
                        .labelsHidden()
                }
            }
            .navigationTitle(tag == nil ? "New Tag" : "Edit Tag")
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
        if let tag {
            if trimmed.caseInsensitiveCompare(tag.name) != .orderedSame {
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
        let saved = Tag(
            id: tag?.id ?? UUID(),
            name: trimmed,
            colorHex: color.toHex(),
            sortOrder: tag?.sortOrder ?? defaultSortOrder,
            createdAt: tag?.createdAt ?? now,
            modifiedAt: now
        )
        onSave(saved)
        dismiss()
    }
}
