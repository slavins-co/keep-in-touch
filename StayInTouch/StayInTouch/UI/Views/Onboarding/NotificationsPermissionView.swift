//
//  NotificationsPermissionView.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

struct NotificationsPermissionView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 64))
            Text("Stay on Track with Reminders")
                .font(.title2)
            Text("We'll send gentle nudges when it's time to reconnect.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Enable Notifications") {
                Task { await viewModel.requestNotificationsPermission() }
            }
            .buttonStyle(.borderedProminent)

            Button("Not Now") {
                viewModel.skipNotifications()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}
