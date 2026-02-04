//
//  NewContactsPickerView.swift
//  StayInTouch
//
//  Created by Codex on 2/3/26.
//

import SwiftUI

struct NewContactsPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let contacts: [ContactSummary]
    let onImport: ([ContactSummary]) -> Void
    let onCancel: () -> Void

    @State private var selection: Set<String> = []

    var body: some View {
        NavigationStack {
            List(contacts, id: \.identifier, selection: $selection) { contact in
                HStack {
                    Text(contact.displayName)
                    Spacer()
                    Text(contact.initials)
                        .foregroundStyle(.secondary)
                }
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
                    Button("Import") {
                        let selected = contacts.filter { selection.contains($0.identifier) }
                        onImport(selected)
                        dismiss()
                    }
                    .disabled(selection.isEmpty)
                }
            }
        }
    }
}
