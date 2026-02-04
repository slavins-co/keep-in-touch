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
        VStack(spacing: 20) {
            Image(systemName: "person.2.circle.fill")
                .font(.system(size: 72))
            Text("Stay in Touch")
                .font(.largeTitle)
            Text("Never lose track of the people who matter")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                Label("Track who you haven't talked to lately", systemImage: "checkmark.circle")
                Label("Get gentle reminders to reach out", systemImage: "checkmark.circle")
                Label("Your data stays on your device", systemImage: "checkmark.circle")
            }
            .font(.callout)
            .padding()

            Button("Get Started") {
                viewModel.goToContactsPermission()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
