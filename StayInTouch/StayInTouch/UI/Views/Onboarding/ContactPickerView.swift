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
        VStack(spacing: DS.Spacing.md) {
            Text("Who Do You Want to Stay in Touch With?")
                .font(DS.Typography.title)
                .padding(.top)

            TextField("Search contacts...", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            if viewModel.contactsAccessLimited {
                LimitedContactsAccessBanner()
                    .padding(.horizontal)
            }

            ScrollViewReader { proxy in
                HStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            ForEach(groupedContacts, id: \.0) { section in
                                Section {
                                    ForEach(section.1) { contact in
                                        Button(action: { viewModel.toggleSelection(for: contact.identifier) }) {
                                            HStack {
                                                Text(contact.displayName)
                                                    .font(DS.Typography.contactName)
                                                Spacer()
                                                if viewModel.selectedContactIds.contains(contact.identifier) {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundStyle(DS.Colors.accent)
                                                } else {
                                                    Image(systemName: "circle")
                                                        .foregroundStyle(DS.Colors.secondaryText)
                                                }
                                            }
                                            .padding(.horizontal, DS.Spacing.lg)
                                            .padding(.vertical, DS.Spacing.md)
                                            .background(DS.Colors.background)
                                        }
                                        .buttonStyle(.plain)
                                        Divider()
                                            .padding(.leading, DS.Spacing.lg)
                                    }
                                } header: {
                                    Text(section.0)
                                        .font(DS.Typography.sectionHeader)
                                        .foregroundStyle(DS.Colors.secondaryText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, DS.Spacing.lg)
                                        .padding(.vertical, DS.Spacing.sm)
                                        .background(DS.Colors.groupedBackground)
                                }
                                .id(section.0)
                            }
                        }
                    }

                    SectionIndexView(sections: groupedContacts.map { $0.0 }) { section in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(section, anchor: .top)
                        }
                    }
                    .padding(.trailing, DS.Spacing.xs)
                }
            }

            Button("Continue") {
                viewModel.continueFromContactPicker()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom)
        }
    }
}
