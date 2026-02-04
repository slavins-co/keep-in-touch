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
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            ForEach(groupedContacts, id: \.0) { section in
                                Section {
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
                                            .padding(.horizontal)
                                            .padding(.vertical, 8)
                                            .background(Color(uiColor: .systemBackground))
                                        }
                                        .buttonStyle(.plain)
                                        Divider()
                                            .padding(.leading)
                                    }
                                } header: {
                                    Text(section.0)
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                        .background(Color(uiColor: .systemGroupedBackground))
                                }
                                .id(section.0)
                            }
                        }
                        .padding(.trailing, 40)
                    }

                    SectionIndexView(sections: groupedContacts.map { $0.0 }) { section in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(section, anchor: .top)
                        }
                    }
                    .padding(.trailing, 8)
                    .allowsHitTesting(true)
                    .zIndex(1)
                }
            }

            Button("Continue") {
                viewModel.continueFromContactPicker()
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom)
        }
    }
}
