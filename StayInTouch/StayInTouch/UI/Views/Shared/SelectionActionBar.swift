//
//  SelectionActionBar.swift
//  KeepInTouch
//

import SwiftUI

/// Floating bottom action bar shown when select mode is active.
/// Mirrors Mail/Photos: Cancel on the left, primary action on the right.
/// Optional `subtitle` renders above the buttons — used by the
/// "Forgot someone?" flow to communicate which group is being added to.
struct SelectionActionBar: View {
    let count: Int
    var subtitle: String? = nil
    let onCancel: () -> Void
    let onCommit: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            if let subtitle {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                    Text(subtitle)
                        .font(DS.Typography.metadata)
                        .foregroundStyle(DS.Colors.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Spacing.sm)
                .accessibilityElement(children: .combine)
            }

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
                    Text(count == 0 ? commitLabel : "\(commitLabel) (\(count))")
                        .font(DS.Typography.ctaButton)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(count == 0 ? DS.Colors.muted : DS.Colors.heroAccentGreen)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(count == 0)
                .accessibilityLabel(commitAccessibilityLabel)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(DS.Colors.ctaContainerBg)
        .overlay(alignment: .top) {
            DS.Colors.borderMedium.frame(height: 1)
        }
    }

    /// "Add to group" reads more naturally than "Log Connection" when
    /// the user is in the "Forgot someone?" follow-up. Drop in the
    /// alternate label whenever a subtitle is present.
    private var commitLabel: String {
        subtitle == nil ? "Log Connection" : "Add to group"
    }

    /// Accessibility label mirrors the visual `commitLabel` so VoiceOver
    /// announces "Add to group" during the "Forgot?" follow-up instead
    /// of the default "Log connection" verb.
    private var commitAccessibilityLabel: String {
        if count == 0 {
            return "\(commitLabel), no contacts selected"
        }
        return "\(commitLabel) with \(count) \(count == 1 ? "contact" : "contacts")"
    }
}
