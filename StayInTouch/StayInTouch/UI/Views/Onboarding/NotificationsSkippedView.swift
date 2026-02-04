//
//  NotificationsSkippedView.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

struct NotificationsSkippedView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 56))
            Text("Notifications Are Off")
                .font(.title2)
            Text("No worries — you can enable reminders anytime in Settings.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Continue") {
                viewModel.finishFromNotificationsSkipped()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
