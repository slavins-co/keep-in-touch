//
//  SelectionActionBar.swift
//  KeepInTouch
//

import SwiftUI

/// Floating bottom action bar shown when select mode is active.
/// Mirrors Mail/Photos: Cancel on the left, primary action on the right.
struct SelectionActionBar: View {
    let count: Int
    let onCancel: () -> Void
    let onCommit: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Button(action: onCancel) {
                Text("Cancel")
                    .font(DS.Typography.ctaButton)
                    .foregroundStyle(DS.Colors.primaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(DS.Colors.secondaryBackground)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel selection")

            Button(action: onCommit) {
                Text(count == 0 ? "Log Connection" : "Log Connection (\(count))")
                    .font(DS.Typography.ctaButton)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(count == 0 ? DS.Colors.muted : DS.Colors.heroAccentGreen)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(count == 0)
            .accessibilityLabel(count == 0 ? "Log connection, no contacts selected" : "Log connection with \(count) contacts")
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(DS.Colors.ctaContainerBg)
        .overlay(alignment: .top) {
            DS.Colors.borderMedium.frame(height: 1)
        }
    }
}
