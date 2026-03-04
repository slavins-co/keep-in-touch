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
    let backgroundColor: Color
    let borderColor: Color

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            Text("\(count)")
                .font(DS.Typography.summaryNumber)
                .foregroundStyle(numberColor)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: count)

            Text(label.uppercased())
                .font(DS.Typography.summaryLabel)
                .tracking(0.55)
                .foregroundStyle(numberColor)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.cardPadding)
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .shadow(color: DS.Shadow.cardColor, radius: DS.Shadow.cardRadius, y: DS.Shadow.cardY)
    }
}
