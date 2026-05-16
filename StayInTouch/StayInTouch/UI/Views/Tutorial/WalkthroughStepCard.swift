//
//  WalkthroughStepCard.swift
//  KeepInTouch
//
//  Visual card rendered for each walkthrough step. Progress bar, title, body,
//  primary CTA, and a Skip button visible on every step except the wrap.
//

import SwiftUI

struct WalkthroughStepCard: View {
    let step: WalkthroughStep
    var onPrimary: () -> Void
    var onSkip: () -> Void

    private var progress: Double {
        guard let index = WalkthroughCoordinator.stepOrder.firstIndex(of: step) else { return 0 }
        let total = max(1, WalkthroughCoordinator.stepOrder.count - 1)
        return Double(index) / Double(total)
    }

    private var progressAccessibilityLabel: String {
        guard let index = WalkthroughCoordinator.stepOrder.firstIndex(of: step) else { return "" }
        return "Step \(index + 1) of \(WalkthroughCoordinator.stepOrder.count)"
    }

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            progressBar

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

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DS.Colors.separator.opacity(0.4))
                Capsule()
                    .fill(DS.Colors.accent)
                    .frame(width: geo.size.width * progress)
            }
        }
        .frame(height: 3)
        .animation(.easeInOut(duration: 0.3), value: progress)
        .accessibilityElement()
        .accessibilityLabel(progressAccessibilityLabel)
    }
}
