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
        VStack(spacing: DS.Spacing.md) {
            Text("Choose a Frequency")
                .font(DS.Typography.title)
                .padding(.top)

            Text("Pick how often you want to keep in touch with each person.")
                .font(DS.Typography.metadata)
                .foregroundStyle(DS.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            List(selectedContacts) { contact in
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text(contact.displayName)
                        .font(DS.Typography.contactName)

                    Picker("Frequency", selection: binding(for: contact.identifier)) {
                        ForEach(viewModel.groups, id: \.id) { group in
                            Text(group.name).tag(group.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.vertical, DS.Spacing.sm)
            }
            .listStyle(.plain)

            Button("Continue") {
                viewModel.continueFromGroupAssignment()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
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
