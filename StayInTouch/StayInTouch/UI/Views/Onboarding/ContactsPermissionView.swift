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
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 56))
                .foregroundStyle(DS.Colors.accent)
            Text("Connect Your Contacts")
                .font(DS.Typography.title)
            Text("We'll help you pick who you want to stay close with. Your contacts never leave your device.")
                .font(DS.Typography.metadata)
                .foregroundStyle(DS.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Allow Access to Contacts") {
                Task { await viewModel.requestContactsPermission() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Skip for Now") {
                viewModel.skipContactsPermission()
            }
            .buttonStyle(.plain)
            .foregroundStyle(DS.Colors.secondaryText)
            Spacer()
        }
        .padding()
    }
}
