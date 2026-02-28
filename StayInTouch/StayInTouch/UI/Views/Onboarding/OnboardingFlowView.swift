//
//  OnboardingFlowView.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

struct OnboardingFlowView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.md) {
                if viewModel.canGoBack {
                    Button {
                        viewModel.goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundStyle(DS.Colors.accent)
                    }
                    .accessibilityLabel("Go back")
                } else {
                    Color.clear.frame(width: 24, height: 24)
                }

                ProgressView(value: viewModel.progressFraction)
                    .tint(DS.Colors.accent)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.sm)

            SwiftUI.Group {
                switch viewModel.step {
                case .welcome:
                    WelcomeView(viewModel: viewModel)
                case .contactsPermission:
                    ContactsPermissionView(viewModel: viewModel)
                case .contactsRequired:
                    ContactsRequiredView(viewModel: viewModel)
                case .contactPicker:
                    ContactPickerView(viewModel: viewModel)
                case .groupAssignment:
                    GroupAssignmentView(viewModel: viewModel)
                case .notificationsPermission:
                    NotificationsPermissionView(viewModel: viewModel)
                case .notificationsSkipped:
                    NotificationsSkippedView(viewModel: viewModel)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.step)
        }
    }
}

#Preview {
    OnboardingFlowView(viewModel: OnboardingViewModel())
}
