//
//  FreshStartPromptView.swift
//  KeepInTouch
//

import SwiftUI

struct FreshStartPromptView: View {
    let reason: FreshStartDetector.Reason
    let onFreshStart: () async -> Void
    let onDismiss: () -> Void

    @State private var showConfirmation = false

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()

            Image(systemName: "arrow.counterclockwise")
                .font(DS.Typography.onboardingIcon)
                .foregroundStyle(DS.Colors.accent)

            Text(titleText)
                .font(DS.Typography.largeTitle)
                .multilineTextAlignment(.center)

            Text(bodyText)
                .font(DS.Typography.metadata)
                .foregroundStyle(DS.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Label("Resets the clock on all your contacts", systemImage: "checkmark.circle.fill")
                Label("Touch history and groups are preserved", systemImage: "checkmark.circle.fill")
                Label("Everything starts clean from today", systemImage: "checkmark.circle.fill")
            }
            .font(DS.Typography.metadata)
            .foregroundStyle(DS.Colors.secondaryText)
            .padding()

            Button("Start Fresh") {
                showConfirmation = true
            }
            .buttonStyle(OnboardingPrimaryButtonStyle())
            .accessibilityHint("Opens confirmation before resetting")

            Button("Not Now") {
                onDismiss()
            }
            .buttonStyle(.plain)
            .font(DS.Typography.metadata)
            .foregroundStyle(DS.Colors.secondaryText)
            .accessibilityHint("Dismisses this suggestion for 30 days")

            Spacer()
        }
        .padding()
        .background(DS.Colors.pageBg.ignoresSafeArea())
        .confirmationDialog(
            "Start Fresh?",
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset the Clock", role: .destructive) {
                Task { await onFreshStart() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This resets the clock on all your contacts so everything starts clean from today. Your touch history, groups, and frequencies are all preserved.")
        }
    }

    // MARK: - Copy

    private var titleText: String {
        switch reason {
        case .inactive, .both: return "Welcome Back!"
        case .overwhelmed:     return "Feeling Behind?"
        }
    }

    private var bodyText: String {
        switch reason {
        case .inactive:
            return "Looks like you've been away for a while. Want to reset the clock on all your contacts and start fresh from today?"
        case .overwhelmed:
            return "Most of your contacts are overdue. Want to reset the clock and start fresh from today?"
        case .both:
            return "Looks like you've been away and things have piled up. Want to reset the clock on all your contacts and start fresh?"
        }
    }
}
