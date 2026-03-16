//
//  AddContactsToCadenceView.swift
//  KeepInTouch
//
//  Created by Codex on 3/3/26.
//

import SwiftUI

struct AddContactsToCadenceView: View {
    @Environment(\.dismiss) private var dismiss

    let available: [Person]
    let onSave: ([UUID]) -> Void
    let onCancel: () -> Void

    @State private var selection: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List(available, id: \.id, selection: $selection) { person in
                Text(person.displayName)
            }
            .navigationTitle("Add Contacts")
            .environment(\.editMode, .constant(.active))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        onSave(Array(selection))
                        dismiss()
                    }
                    .disabled(selection.isEmpty)
                }
            }
        }
    }
}
