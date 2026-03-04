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
        .padding(14)
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}
