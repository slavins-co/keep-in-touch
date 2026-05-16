//
//  WalkthroughStepCard.swift
//  KeepInTouch
//
//  Visual card rendered for each walkthrough step. Title, body, primary CTA,
//  and an optional Skip button. Uses ViewThatFits to adapt to large Dynamic Type.
//

import SwiftUI

struct WalkthroughStepCard: View {
    let step: WalkthroughStep
    var onPrimary: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Text(step.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(DS.Colors.primaryText)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)

            Text(step.body)
                .font(.subheadline)
                .foregroundStyle(DS.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if step == .homeSwipeDemo {
                SwipeDemoView()
                    .padding(.vertical, DS.Spacing.xs)
            }

            Button(action: onPrimary) {
                Text(step.primaryCTA)
            }
            .buttonStyle(OnboardingPrimaryButtonStyle())
            .accessibilityIdentifier("tutorial-primary-cta")

            if step.showsSkipButton {
                Button(action: onSkip) {
                    Text("Skip tour")
                        .font(.subheadline)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
                .accessibilityIdentifier("tutorial-skip")
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: 320)
        .background(DS.Colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
        .padding(.horizontal, DS.Spacing.md)
    }
}
