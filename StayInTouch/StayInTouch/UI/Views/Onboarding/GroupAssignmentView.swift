//
//  GroupAssignmentView.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

struct GroupAssignmentView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 12) {
            Text("Choose a Cadence")
                .font(.title2)
                .padding(.top)

            Text("Pick how often you want to stay in touch with each person.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            List(selectedContacts) { contact in
                VStack(alignment: .leading, spacing: 8) {
                    Text(contact.displayName)
                        .font(.headline)

                    Picker("Group", selection: binding(for: contact.identifier)) {
                        ForEach(viewModel.groups, id: \.id) { group in
                            Text(group.name).tag(group.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.vertical, 6)
            }
            .listStyle(.plain)

            Button("Continue") {
                viewModel.continueFromGroupAssignment()
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom)
        }
    }

    private var selectedContacts: [ContactSummary] {
        viewModel.contacts.filter { viewModel.selectedContactIds.contains($0.identifier) }
    }

    private func binding(for contactId: String) -> Binding<UUID> {
        let fallback = viewModel.selectedGroupId ?? viewModel.groups.first?.id ?? UUID()
        return Binding<UUID>(
            get: {
                viewModel.contactGroupSelections[contactId] ?? fallback
            },
            set: { newValue in
                viewModel.contactGroupSelections[contactId] = newValue
            }
        )
    }
}
