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
        HStack(alignment: .top, spacing: 0) {
            // Timeline column
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(DS.Colors.timelineCircleFill)
                    Circle()
                        .stroke(
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

            // Content column
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack {
                    Text(event.method.rawValue)
                        .font(DS.Typography.timelineTitle)
                    Spacer()
                    Text(event.at.formatted(date: .abbreviated, time: .omitted))
                        .font(DS.Typography.timelineMono)
                        .foregroundStyle(Color(.secondaryLabel))
                }
                if let notes = event.notes, !notes.isEmpty {
                    Text(notes)
                        .font(DS.Typography.timelineNotes)
                        .foregroundStyle(Color(.label).opacity(0.7))
                }
            }
            .padding(.leading, DS.Spacing.xxl)
        }
        .padding(.bottom, DS.Spacing.xxxl)
    }
}
