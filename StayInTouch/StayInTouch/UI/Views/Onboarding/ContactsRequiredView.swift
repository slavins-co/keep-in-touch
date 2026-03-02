//
//  ContactsRequiredView.swift
//  KeepInTouch
//
//  Created by Codex on 2/3/26.
//

import SwiftUI

struct ContactsRequiredView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 56))
                .foregroundStyle(DS.Colors.accent)

            VStack(spacing: DS.Spacing.md) {
                Text("Contacts Power the App")
                    .font(DS.Typography.title)
                    .multilineTextAlignment(.center)

                Text("Keep In Touch needs your contacts to track check-ins and reminders. You can enable access later in Settings.")
                    .font(DS.Typography.metadata)
                    .foregroundStyle(DS.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }

            Toggle("Use demo data for now", isOn: $viewModel.useDemoData)
                .toggleStyle(.switch)
                .padding(.horizontal)

            Button {
                Task { await viewModel.requestContactsPermissionFromRequired() }
            } label: {
                Text("Enable Contacts Now")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .foregroundStyle(DS.Colors.secondaryText)
            .padding(.horizontal)

            Button {
                viewModel.continueFromContactsRequired()
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }
}
