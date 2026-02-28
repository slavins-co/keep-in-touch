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
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 56))
                .foregroundStyle(DS.Colors.accent)
            Text("Stay on Track with Reminders")
                .font(DS.Typography.title)
            Text("We'll send gentle nudges when it's time to reconnect.")
                .font(DS.Typography.metadata)
                .foregroundStyle(DS.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Enable Notifications") {
                Task { await viewModel.requestNotificationsPermission() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Not Now") {
                viewModel.skipNotifications()
            }
            .buttonStyle(.plain)
            .foregroundStyle(DS.Colors.secondaryText)
            Spacer()
        }
        .padding()
    }
}
