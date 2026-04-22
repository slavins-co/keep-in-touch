//
//  KeepInTouchWidget.swift
//  KeepInTouchWidget
//

import SwiftUI
import WidgetKit

struct OverdueEntry: TimelineEntry {
    let date: Date
    let configuration: OverdueWidgetConfigurationIntent
    let snapshot: WidgetDataProvider.Snapshot
}

struct OverdueTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> OverdueEntry {
        OverdueEntry(
            date: Date(),
            configuration: OverdueWidgetConfigurationIntent(),
            snapshot: .placeholder
        )
    }

    func snapshot(for configuration: OverdueWidgetConfigurationIntent, in context: Context) async -> OverdueEntry {
        OverdueEntry(
            date: Date(),
            configuration: configuration,
            snapshot: WidgetDataProvider.loadSnapshot()
        )
    }

    func timeline(for configuration: OverdueWidgetConfigurationIntent, in context: Context) async -> Timeline<OverdueEntry> {
        let now = Date()
        let entry = OverdueEntry(
            date: now,
            configuration: configuration,
            snapshot: WidgetDataProvider.loadSnapshot(now: now)
        )
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }
}

extension WidgetDataProvider.Snapshot {
    static let placeholder = WidgetDataProvider.Snapshot(
        overdueCount: 3,
        featured: [
            OverduePerson(
                id: UUID(),
                displayName: "Alex",
                initials: "A",
                avatarColorHex: "#FF6B6B",
                groupColorHex: nil,
                daysOverdue: 5
            )
        ],
        hasTrackedPeople: true
    )
}

struct OverdueWidgetEntryView: View {
    var entry: OverdueEntry

    var body: some View {
        VStack(spacing: 6) {
            if entry.snapshot.overdueCount == 0 {
                Text(entry.snapshot.hasTrackedPeople ? "All caught up" : "Add someone to track")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("\(entry.snapshot.overdueCount)")
                    .font(.largeTitle.weight(.semibold))
                if let first = entry.snapshot.featured.first {
                    Text(first.displayName)
                        .font(.caption)
                        .lineLimit(1)
                    Text("+\(first.daysOverdue)d overdue")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct OverdueWidget: Widget {
    let kind: String = "OverdueWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: OverdueWidgetConfigurationIntent.self,
            provider: OverdueTimelineProvider()
        ) { entry in
            OverdueWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Keep In Touch")
        .description("Shows who needs a touch today.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    OverdueWidget()
} timeline: {
    OverdueEntry(date: .now, configuration: OverdueWidgetConfigurationIntent(), snapshot: .placeholder)
}
