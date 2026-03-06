//
//  LastTouchSeedingView.swift
//  KeepInTouch
//

import SwiftUI

struct LastTouchSeedingView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Text("When Did You Last Connect?")
                .font(DS.Typography.title)
                .padding(.top)

            Text("This helps calculate when you're next due to reach out.")
                .font(DS.Typography.metadata)
                .foregroundStyle(DS.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            List(selectedContacts) { contact in
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text(contact.displayName)
                        .font(DS.Typography.contactName)

                    Picker("Last connected", selection: binding(for: contact.identifier)) {
                        ForEach(LastTouchOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.vertical, DS.Spacing.sm)
            }
            .listStyle(.plain)

            Button("Continue") {
                viewModel.continueFromLastTouchSeeding()
            }
            .buttonStyle(OnboardingPrimaryButtonStyle())
            .disabled(viewModel.isImporting)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    private var selectedContacts: [ContactSummary] {
        viewModel.contacts.filter { viewModel.selectedContactIds.contains($0.identifier) }
    }

    private func binding(for contactId: String) -> Binding<LastTouchOption> {
        Binding<LastTouchOption>(
            get: {
                viewModel.contactLastTouchSelections[contactId] ?? .cantRemember
            },
            set: { newValue in
                viewModel.contactLastTouchSelections[contactId] = newValue
            }
        )
    }
}
