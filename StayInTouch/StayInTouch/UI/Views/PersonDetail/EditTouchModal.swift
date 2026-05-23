//
//  EditTouchModal.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

struct EditTouchModal: View {
    @Environment(\.dismiss) private var dismiss

    let touch: TouchEvent
    let onSave: (TouchMethod, String?, TimeOfDay?) -> Void
    let onDelete: (() -> Void)?

    @State private var selectedMethod: TouchMethod
    @State private var notes: String
    @State private var selectedTimeOfDay: TimeOfDay?
    @State private var showDeleteConfirm = false

    init(touch: TouchEvent, onSave: @escaping (TouchMethod, String?, TimeOfDay?) -> Void, onDelete: (() -> Void)? = nil) {
        self.touch = touch
        self.onSave = onSave
        self.onDelete = onDelete
        _selectedMethod = State(initialValue: touch.method)
        _notes = State(initialValue: touch.notes ?? "")
        _selectedTimeOfDay = State(initialValue: touch.timeOfDay)
    }

    var body: some View {
        NavigationStack {
            Form {
                Text("Date: \(touch.at.formatted(date: .abbreviated, time: .omitted))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TouchMethodPicker(selection: $selectedMethod)

                TouchTimeAndNotesFields(
                    selectedTimeOfDay: $selectedTimeOfDay,
                    notes: $notes
                )

                if onDelete != nil {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                Label("Delete Connection", systemImage: "trash")
                                Spacer()
                            }
                        }
                        .accessibilityLabel("Delete this connection")
                        .accessibilityHint("Permanently removes this connection entry")
                    }
                }
            }
            .navigationTitle("Edit Connection")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(selectedMethod, notes.isEmpty ? nil : notes, selectedTimeOfDay)
                        dismiss()
                    }
                }
            }
            .alert("Delete connection?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    Haptics.medium()
                    onDelete?()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This can't be undone.")
            }
        }
    }
}
