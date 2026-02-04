//
//  ContactPickerView.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

struct ContactPickerView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    private var groupedContacts: [(String, [ContactSummary])] {
        let grouped = Dictionary(grouping: viewModel.filteredContacts) { contact -> String in
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
        VStack(spacing: 12) {
            Text("Who Do You Want to Stay in Touch With?")
                .font(.title2)
                .padding(.top)

            TextField("Search contacts...", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            ZStack(alignment: .trailing) {
                List {
                    ForEach(groupedContacts, id: \.0) { section in
                        Section(header: Text(section.0)) {
                            ForEach(section.1) { contact in
                                Button(action: { viewModel.toggleSelection(for: contact.identifier) }) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(contact.displayName)
                                            Text(contact.initials)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if viewModel.selectedContactIds.contains(contact.identifier) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.blue)
                                        } else {
                                            Image(systemName: "circle")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
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

            Button("Continue") {
                viewModel.continueFromContactPicker()
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom)
        }
    }
}
