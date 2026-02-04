//
//  ContactPickerView.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

struct ContactPickerView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 12) {
            Text("Who Do You Want to Track?")
                .font(.title2)
                .padding(.top)

            TextField("Search contacts...", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            List(viewModel.filteredContacts) { contact in
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
            .listStyle(.plain)

            Button("Continue") {
                viewModel.continueFromContactPicker()
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom)
        }
    }
}
