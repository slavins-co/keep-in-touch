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
