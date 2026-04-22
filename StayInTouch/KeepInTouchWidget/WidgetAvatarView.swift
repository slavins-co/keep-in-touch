//
//  WidgetAvatarView.swift
//  KeepInTouchWidget
//
//  Colored-circle + initials avatar, with optional "+N" days-overdue
//  badge and status ring. Mirrors the main app's avatar look without
//  importing its design system (widgets run in their own process).
//

import SwiftUI

struct WidgetAvatarView: View {
    let initials: String
    let colorHex: String
    let daysOverdueBadge: Int?
    let diameter: CGFloat

    init(
        initials: String,
        colorHex: String,
        daysOverdueBadge: Int? = nil,
        diameter: CGFloat = 40
    ) {
        self.initials = initials
        self.colorHex = colorHex
        self.daysOverdueBadge = daysOverdueBadge
        self.diameter = diameter
    }

    var body: some View {
        Circle()
            .fill(Color(hex: colorHex) ?? .gray)
            .frame(width: diameter, height: diameter)
            .overlay(
                Text(initials)
                    .font(.system(size: diameter * 0.4, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .overlay(alignment: .topTrailing) {
                if let days = daysOverdueBadge, days > 0 {
                    Text("+\(days)")
                        .font(.system(size: diameter * 0.28, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.red, in: Capsule())
                        .offset(x: 4, y: -4)
                }
            }
    }
}

extension Color {
    init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else {
            return nil
        }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
