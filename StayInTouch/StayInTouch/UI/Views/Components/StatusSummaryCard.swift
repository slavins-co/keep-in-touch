//
//  StatusSummaryCard.swift
//  KeepInTouch
//
//  Summary status card for the Home screen (Issue #174).
//

import SwiftUI

struct StatusSummaryCard: View {
    let count: Int
    let label: String
    let numberColor: Color
    let labelColor: Color
    let backgroundColor: Color
    let borderColor: Color

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            // DESIGN: Light/dark structural difference — summary card numbers: 28px light / 24px dark
            Text("\(count)")
                .font(DS.Typography.summaryNumber(scheme: colorScheme))
                .foregroundStyle(numberColor)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: count)

            // DESIGN: Light/dark structural difference — summary card labels: status-colored light / all gray-500 dark
            Text(label.uppercased())
                .font(DS.Typography.summaryLabel)
                .tracking(0.55)
                .foregroundStyle(labelColor)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.cardPadding)
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .shadow(color: DS.Colors.summaryCardShadow, radius: DS.Shadow.cardRadius, y: DS.Shadow.cardY)
        .accessibilityElement(children: .combine)
    }
}
