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
    @State private var searchText = ""

    private var groupedContacts: [(String, [ContactSummary])] {
        let filtered = searchText.isEmpty ? contacts : contacts.filter { contact in
            contact.displayName.localizedCaseInsensitiveContains(searchText)
        }

        let grouped = Dictionary(grouping: filtered) { contact -> String in
            let firstChar = contact.displayName.prefix(1).uppercased()
            return firstChar.rangeOfCharacter(from: CharacterSet.letters) != nil ? firstChar : "#"
        }

        return grouped.sorted { lhs, rhs in
            if lhs.key == "#" { return false }
            if rhs.key == "#" { return true }
            return lhs.key < rhs.key
        }.map { (key, contacts) in
            (key, contacts.sorted { $0.displayName < $1.displayName })
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("Search contacts...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                ZStack(alignment: .trailing) {
                    List(selection: $selection) {
                        ForEach(groupedContacts, id: \.0) { section in
                            Section(header: Text(section.0)) {
                                ForEach(section.1, id: \.identifier) { contact in
                                    HStack {
                                        Text(contact.displayName)
                                        Spacer()
                                        Text(contact.initials)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)

                    SectionIndexView(sections: groupedContacts.map { $0.0 }) { _ in
                        // Scroll functionality would require ScrollViewReader
                        // Simplified for now - just shows the index
                    }
                    .padding(.trailing, 4)
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
