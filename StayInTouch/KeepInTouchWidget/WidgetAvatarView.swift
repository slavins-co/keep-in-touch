//
//  WidgetAvatarView.swift
//  KeepInTouchWidget
//
//  Colored-circle + initials avatar, optionally wrapped in a status
//  ring. Mirrors the main app's avatar look without importing its
//  design system (widgets run in their own process).
//

import SwiftUI

struct WidgetAvatarView: View {
    let initials: String
    let colorHex: String
    let statusRingColor: Color?
    let diameter: CGFloat

    init(
        initials: String,
        colorHex: String,
        statusRingColor: Color? = nil,
        diameter: CGFloat = 40
    ) {
        self.initials = initials
        self.colorHex = colorHex
        self.statusRingColor = statusRingColor
        self.diameter = diameter
    }

    var body: some View {
        Circle()
            .fill(Color(hex: colorHex))
            .frame(width: diameter, height: diameter)
            .overlay(
                Text(initials)
                    .font(.system(size: diameter * 0.4, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .overlay(
                Circle()
                    .stroke(statusRingColor ?? .clear, lineWidth: 2)
                    .padding(-3)
            )
    }
}

/// Overlapping avatar coins for people sharing the same day (#329). Renders up
/// to 3; the primary (first) sits on top-left and reads first. A background-
/// colored separator ring keeps overlapping coins distinct.
struct StackedAvatarsView: View {
    let avatars: [(initials: String, colorHex: String)]
    var diameter: CGFloat = 32

    var body: some View {
        let shown = Array(avatars.prefix(3))
        HStack(spacing: -diameter * 0.42) {
            ForEach(Array(shown.enumerated()), id: \.offset) { index, avatar in
                WidgetAvatarView(initials: avatar.initials, colorHex: avatar.colorHex, diameter: diameter)
                    .overlay(
                        Circle().stroke(Color(uiColor: .systemBackground), lineWidth: 1.5)
                    )
                    .zIndex(Double(shown.count - index))  // primary on top
            }
        }
    }
}

/// Avatar treatment for a birthday cohort on single-slot surfaces: a single
/// ringed avatar when alone, overlapping coins when several share the day.
struct BirthdayCohortAvatars: View {
    let cohort: BirthdayCohort
    var diameter: CGFloat = 32

    var body: some View {
        if cohort.additionalCount > 0 {
            StackedAvatarsView(
                avatars: cohort.stackedAvatars.map { ($0.initials, $0.avatarColorHex) },
                diameter: diameter
            )
        } else {
            WidgetAvatarView(
                initials: cohort.primary.initials,
                colorHex: cohort.primary.avatarColorHex,
                statusRingColor: BrandColors.heroAccentGreen,
                diameter: diameter
            )
        }
    }
}
