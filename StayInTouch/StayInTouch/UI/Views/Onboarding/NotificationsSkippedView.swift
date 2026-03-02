//
//  NotificationsSkippedView.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

struct NotificationsSkippedView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 56))
                .foregroundStyle(DS.Colors.accent)
            Text("Notifications Are Off")
                .font(DS.Typography.title)
            Text("No worries — you can enable reminders anytime in Settings.")
                .font(DS.Typography.metadata)
                .foregroundStyle(DS.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Continue") {
                viewModel.finishFromNotificationsSkipped()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer()
        }
        .padding()
    }
}
