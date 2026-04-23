//
//  AllCaughtUpView.swift
//  KeepInTouch
//
//  Celebratory banner shown on Home when the user is tracking contacts
//  but none are overdue or due soon. Mirrors the widget's all-caught-up
//  state from #282 so the two surfaces feel consistent (#283).
//

import SwiftUI

struct AllCaughtUpView: View {
    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "hand.wave.fill")
                .font(.system(size: 44))
                .foregroundStyle(DS.Colors.heroAccentGreen)
                .accessibilityHidden(true)

            Text("You've reached out to everyone.\nWay to go!")
                .font(DS.Typography.title)
                .multilineTextAlignment(.center)
                .foregroundStyle(DS.Colors.primaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.xl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("You've reached out to everyone. Way to go.")
    }
}

#Preview {
    AllCaughtUpView()
}
