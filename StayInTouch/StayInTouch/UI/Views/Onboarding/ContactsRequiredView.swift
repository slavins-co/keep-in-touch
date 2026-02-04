//
//  ContactsRequiredView.swift
//  StayInTouch
//
//  Created by Codex on 2/3/26.
//

import SwiftUI

struct ContactsRequiredView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 56))
                .foregroundStyle(.orange)

            VStack(spacing: 12) {
                Text("Contacts Power the App")
                    .font(.title2)
                    .multilineTextAlignment(.center)

                Text("Stay in Touch needs your contacts to track check-ins and reminders. You can enable access later in Settings.")
                    .font(.body)
                    .foregroundStyle(.secondary)
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
            .buttonStyle(.bordered)
            .padding(.horizontal)

            Button {
                viewModel.continueFromContactsRequired()
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }
}
