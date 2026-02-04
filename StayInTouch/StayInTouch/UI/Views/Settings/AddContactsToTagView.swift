//
//  AddContactsToTagView.swift
//  StayInTouch
//
//  Created by Codex on 2/3/26.
//

import SwiftUI

struct AddContactsToTagView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.editMode) private var editMode

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
