//
//  CadencePerformanceChart.swift
//  KeepInTouch
//

import Charts
import SwiftUI

struct CadencePerformanceChart: View {
    let rows: [StatsSnapshot.CadenceRow]
    let range: StatsRange

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader

            if rows.isEmpty {
                Text("No cadences yet. Add a frequency in Settings to start tracking performance.")
                    .font(DS.Typography.metadata)
                    .foregroundStyle(DS.Colors.secondaryText)
                    .padding(.vertical, DS.Spacing.md)
            } else {
                ForEach(rows) { row in
                    rowView(row)
                }
            }
        }
    }

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text("Performance vs Intent")
                .font(DS.Typography.title)
            Text("How often you reached out, compared to each cadence's frequency.")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondaryText)
        }
    }

    @ViewBuilder
    private func rowView(_ row: StatsSnapshot.CadenceRow) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.name)
                    .font(DS.Typography.contactName)
                Spacer()
                trailingLabel(row)
            }

            if let ratio = row.ratio, row.expected > 0 {
                bar(ratio: ratio, row: row)
            } else {
                infoText(for: row)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: row))
    }

    private func bar(ratio: Double, row: StatsSnapshot.CadenceRow) -> some View {
        let display = min(ratio, 1.0)
        return Chart {
            BarMark(
                xStart: .value("Start", 0),
                xEnd: .value("End", display),
                y: .value("Cadence", row.name)
            )
            .foregroundStyle(barGradient(for: ratio))
            .cornerRadius(DS.Radius.sm, style: .continuous)
        }
        .chartXScale(domain: 0...1)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 22)
    }

    private func barGradient(for ratio: Double) -> LinearGradient {
        let endColor: Color = {
            if ratio >= 0.85 { return DS.Colors.statusAllGood }
            if ratio >= 0.5 { return DS.Colors.statusDueSoon }
            return DS.Colors.statusOverdue
        }()
        return LinearGradient(
            colors: [endColor.opacity(0.6), endColor],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    @ViewBuilder
    private func trailingLabel(_ row: StatsSnapshot.CadenceRow) -> some View {
        if let ratio = row.ratio {
            if ratio > 1.0 {
                HStack(spacing: DS.Spacing.xxs) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Ahead")
                }
                .font(DS.Typography.captionBold)
                .foregroundStyle(DS.Colors.statusAllGood)
            } else {
                Text("\(Int((ratio * 100).rounded()))%")
                    .font(DS.Typography.captionBold)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
        }
    }

    @ViewBuilder
    private func infoText(for row: StatsSnapshot.CadenceRow) -> some View {
        if row.trackedCount == 0 {
            Text("No tracked contacts at this cadence.")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.tertiaryText)
        } else {
            Text("Range too short for this cadence.")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.tertiaryText)
        }
    }

    private func accessibilityLabel(for row: StatsSnapshot.CadenceRow) -> String {
        if let ratio = row.ratio, row.expected > 0 {
            let pct = Int((ratio * 100).rounded())
            return "\(row.name) cadence: \(row.actual) of \(row.expected) expected touches, \(pct) percent"
        }
        if row.trackedCount == 0 {
            return "\(row.name) cadence: no tracked contacts"
        }
        return "\(row.name) cadence: range too short to compare \(range.displayName)"
    }
}
