//
//  ContactsPermissionView.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

struct ContactsPermissionView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 64))
            Text("Connect Your Contacts")
                .font(.title)
            Text("We'll help you pick who you want to stay close with. Your contacts never leave your device.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Allow Access to Contacts") {
                Task { await viewModel.requestContactsPermission() }
            }
            .buttonStyle(.borderedProminent)

            Button("Skip for Now") {
                viewModel.skipContactsPermission()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}
