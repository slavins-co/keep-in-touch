//
//  WelcomeView.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

struct WelcomeView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()
            Image(systemName: "person.2.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(DS.Colors.accent)
            Text("Keep In Touch")
                .font(DS.Typography.largeTitle)
            Text("Never lose track of the people who matter")
                .font(DS.Typography.metadata)
                .foregroundStyle(DS.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Label("Track who you haven't talked to lately", systemImage: "checkmark.circle.fill")
                Label("Get gentle reminders to reach out", systemImage: "checkmark.circle.fill")
                Label("Your data stays on your device", systemImage: "checkmark.circle.fill")
            }
            .font(DS.Typography.metadata)
            .foregroundStyle(DS.Colors.statusAllGood)
            .padding()

            Button("Get Started") {
                viewModel.goToContactsPermission()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer()
        }
        .padding()
    }
}
