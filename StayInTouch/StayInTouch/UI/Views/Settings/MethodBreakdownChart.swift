//
//  MethodBreakdownChart.swift
//  KeepInTouch
//

import Charts
import SwiftUI

struct MethodBreakdownChart: View {
    let rows: [StatsSnapshot.MethodRow]
    let totalEvents: Int

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader

            if rows.isEmpty {
                Text("No connections in this range.")
                    .font(DS.Typography.metadata)
                    .foregroundStyle(DS.Colors.secondaryText)
                    .padding(.vertical, DS.Spacing.md)
            } else {
                HStack(alignment: .center, spacing: DS.Spacing.lg) {
                    donut
                    legend
                }
                .padding(DS.Spacing.md)
                .background(DS.Colors.background)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            }
        }
    }

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text("How you showed up")
                .font(DS.Typography.title)
            Text("Breakdown of \(totalEvents) connection\(totalEvents == 1 ? "" : "s") by method.")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondaryText)
        }
    }

    private var donut: some View {
        Chart(rows) { row in
            SectorMark(
                angle: .value("Count", row.count),
                innerRadius: .ratio(0.6),
                angularInset: 1.5
            )
            .cornerRadius(2)
            .foregroundStyle(color(for: row.method))
        }
        .frame(width: 120, height: 120)
        .accessibilityLabel("Method breakdown donut chart")
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            ForEach(rows) { row in
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: DS.touchMethodIcon(row.method))
                        .foregroundStyle(color(for: row.method))
                        .frame(width: 18)
                    Text(row.method.rawValue)
                        .font(DS.Typography.metadata)
                    Spacer()
                    Text("\(Int((row.percent * 100).rounded()))%")
                        .font(DS.Typography.captionBold)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(row.method.rawValue): \(row.count) connection\(row.count == 1 ? "" : "s"), \(Int((row.percent * 100).rounded())) percent")
            }
        }
    }

    private func color(for method: TouchMethod) -> Color {
        // Stable per-method palette using DS status colors and accent
        switch method {
        case .text:     return DS.Colors.accent
        case .call:     return DS.Colors.statusAllGood
        case .irl:      return DS.Colors.statusDueSoon
        case .email:    return DS.Colors.statusUnknown
        case .facetime: return DS.Colors.statusOverdue
        case .other:    return DS.Colors.muted
        }
    }
}
