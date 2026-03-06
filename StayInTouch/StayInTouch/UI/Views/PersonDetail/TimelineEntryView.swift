//
//  TimelineEntryView.swift
//  KeepInTouch
//

import SwiftUI

struct TimelineEntryView: View {
    let event: TouchEvent
    let isLatest: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            // Timeline column — line extends through content bottom padding
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(DS.Colors.timelineCircleFill)
                    Circle()
                        .strokeBorder(
                            isLatest ? DS.Colors.timelineCircleLatest : DS.Colors.timelineCircleOther,
                            lineWidth: isLatest ? 3 : 2
                        )
                }
                .frame(width: 16, height: 16)

                if !isLast {
                    Rectangle()
                        .fill(DS.Colors.timelineLine)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 16)

            // Content column — bottom padding here so timeline line bridges the gap
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack {
                    Text("\(event.method.rawValue)\(event.timeOfDay.map { " \u{00B7} \($0.rawValue)" } ?? "")")
                        .font(DS.Typography.timelineTitle)
                    Spacer()
                    Text(event.at.formatted(date: .abbreviated, time: .omitted))
                        .font(DS.Typography.timelineMono)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
                if let notes = event.notes, !notes.isEmpty {
                    Text(notes)
                        .font(DS.Typography.timelineNotes)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
            }
            .padding(.bottom, isLast ? 0 : DS.Spacing.lg)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Opens editor with additional options")
    }

    private var accessibilityDescription: String {
        let method = event.method.rawValue
        let date = event.at.formatted(date: .abbreviated, time: .omitted)
        let timeOfDay = event.timeOfDay.map { ", \($0.rawValue)" } ?? ""
        let notes = event.notes.map { ", \($0)" } ?? ""
        return "\(method)\(timeOfDay) on \(date)\(notes)"
    }
}
