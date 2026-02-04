//
//  EditTouchModal.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

struct EditTouchModal: View {
    @Environment(\.dismiss) private var dismiss

    let touch: TouchEvent
    let onSave: (TouchMethod, String?) -> Void

    @State private var selectedMethod: TouchMethod
    @State private var notes: String

    init(touch: TouchEvent, onSave: @escaping (TouchMethod, String?) -> Void) {
        self.touch = touch
        self.onSave = onSave
        _selectedMethod = State(initialValue: touch.method)
        _notes = State(initialValue: touch.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Text("Date: \(touch.at.formatted(date: .abbreviated, time: .shortened))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Picker("Method", selection: $selectedMethod) {
                    ForEach(TouchMethod.allCases, id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }

                TextField("Notes", text: $notes, axis: .vertical)
            }
            .navigationTitle("Edit Touch")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(selectedMethod, notes.isEmpty ? nil : notes)
                        dismiss()
                    }
                }
            }
        }
    }
}
