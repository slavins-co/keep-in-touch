//
//  OnboardingFlowView.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

struct OnboardingFlowView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.showsProgress {
                HStack(spacing: DS.Spacing.md) {
                    Button {
                        viewModel.goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundStyle(DS.Colors.accent)
                    }
                    .accessibilityLabel("Go back")
                    .opacity(viewModel.canGoBack && !viewModel.isCompleting ? 1 : 0)
                    .disabled(!viewModel.canGoBack || viewModel.isCompleting)

                    OnboardingProgressBar(fraction: viewModel.progressFraction)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.sm)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

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
                case .lastTouchSeeding:
                    LastTouchSeedingView(viewModel: viewModel)
                case .notificationsPermission:
                    NotificationsPermissionView(viewModel: viewModel)
                case .notificationsSkipped:
                    NotificationsSkippedView(viewModel: viewModel)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.step)
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.showsProgress)
    }
}

// MARK: - Custom Progress Bar

private struct OnboardingProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DS.Colors.muted)
                    .frame(height: 6)

                Capsule()
                    .fill(DS.Colors.accent)
                    .frame(width: geometry.size.width * CGFloat(fraction), height: 6)
                    .animation(.easeInOut(duration: 0.3), value: fraction)
            }
        }
        .frame(height: 6)
        .accessibilityLabel("Onboarding progress")
        .accessibilityValue("\(Int(fraction * 100)) percent")
    }
}

#Preview {
    OnboardingFlowView(viewModel: OnboardingViewModel())
}
