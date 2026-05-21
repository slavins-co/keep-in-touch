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
                Text("No frequencies yet. Add one in Settings to start tracking performance.")
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
            Text("Touches you logged vs. the target for each frequency.")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondaryText)
        }
    }

    @ViewBuilder
    private func rowView(_ row: StatsSnapshot.CadenceRow) -> some View {
        let isMeasurable = row.ratio != nil && row.expected > 0

        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.name)
                    .font(DS.Typography.contactName)
                    .foregroundStyle(isMeasurable ? DS.Colors.primaryText : DS.Colors.secondaryText)
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
        .background(isMeasurable ? DS.Colors.background : DS.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .opacity(isMeasurable ? 1.0 : 0.7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: row))
    }

    private func bar(ratio: Double, row: StatsSnapshot.CadenceRow) -> some View {
        let display = min(ratio, 1.0)
        return Chart {
            BarMark(
                xStart: .value("Start", 0),
                xEnd: .value("End", display),
                y: .value("Frequency", row.name)
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
            Text("No tracked contacts at this frequency.")
                .font(DS.Typography.caption.italic())
                .foregroundStyle(DS.Colors.tertiaryText)
        } else {
            HStack(spacing: DS.Spacing.xxs) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.caption)
                Text(rangeTooShortMessage(for: row))
                    .font(DS.Typography.caption.italic())
            }
            .foregroundStyle(DS.Colors.tertiaryText)
        }
    }

    private func rangeTooShortMessage(for row: StatsSnapshot.CadenceRow) -> String {
        let base = "Range shorter than \(row.frequencyDays)-day frequency"
        return range == .days30 ? "\(base) — switch to 90 days to compare." : "\(base)."
    }

    private func accessibilityLabel(for row: StatsSnapshot.CadenceRow) -> String {
        if let ratio = row.ratio, row.expected > 0 {
            let pct = Int((ratio * 100).rounded())
            return "\(row.name) frequency: \(row.actual) of \(row.expected) expected touches, \(pct) percent"
        }
        if row.trackedCount == 0 {
            return "\(row.name) frequency: no tracked contacts"
        }
        return "\(row.name) frequency: range too short to compare; \(range == .days30 ? "switch to 90 days" : "no data")"
    }
}
