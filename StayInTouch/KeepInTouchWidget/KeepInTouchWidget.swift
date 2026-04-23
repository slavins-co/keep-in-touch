//
//  KeepInTouchWidget.swift
//  KeepInTouchWidget
//

import AppIntents
import SwiftUI
import UIKit
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
            snapshot: WidgetDataProvider.loadSnapshot(groupFilter: configuredFilter(configuration))
        )
    }

    func timeline(for configuration: OverdueWidgetConfigurationIntent, in context: Context) async -> Timeline<OverdueEntry> {
        let now = Date()
        let entry = OverdueEntry(
            date: now,
            configuration: configuration,
            snapshot: WidgetDataProvider.loadSnapshot(now: now, groupFilter: configuredFilter(configuration))
        )
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    private func configuredFilter(_ configuration: OverdueWidgetConfigurationIntent) -> UUID? {
        guard let id = configuration.group?.id, id != GroupAppEntity.allGroupsID else {
            return nil
        }
        return id
    }
}

extension WidgetDataProvider.Snapshot {
    static let placeholder = WidgetDataProvider.Snapshot(
        overdueCount: 2,
        featured: [
            OverduePerson(id: UUID(), displayName: "Alex", initials: "A", avatarColorHex: "#FF6B6B", groupName: "Weekly", groupColorHex: "#4ECDC4", status: .overdue(daysOverdue: 5)),
            OverduePerson(id: UUID(), displayName: "Sam", initials: "S", avatarColorHex: "#4ECDC4", groupName: "Monthly", groupColorHex: "#FFD166", status: .overdue(daysOverdue: 1)),
            OverduePerson(id: UUID(), displayName: "Jordan", initials: "J", avatarColorHex: "#FFD166", groupName: "Quarterly", groupColorHex: "#A78BFA", status: .dueSoon(daysUntilDue: 2)),
        ],
        hasTrackedPeople: true,
        themeOverride: nil
    )

    static let empty = WidgetDataProvider.Snapshot(overdueCount: 0, featured: [], hasTrackedPeople: false, themeOverride: nil)
    static let allCaughtUp = WidgetDataProvider.Snapshot(overdueCount: 0, featured: [], hasTrackedPeople: true, themeOverride: nil)
}

private extension WidgetPersonStatus {
    var ringColor: Color {
        switch self {
        case .overdue: return .red
        case .dueSoon: return .orange
        }
    }

    var subtitle: String {
        switch self {
        case .overdue(let days):
            return "\(days) day\(days == 1 ? "" : "s") overdue"
        case .dueSoon(let days):
            return days == 0 ? "Due today" : "Due in \(days) day\(days == 1 ? "" : "s")"
        }
    }

    var shortSubtitle: String {
        switch self {
        case .overdue(let days):
            return "\(days)d overdue"
        case .dueSoon(let days):
            return days == 0 ? "Due today" : "Due in \(days)d"
        }
    }
}

// MARK: - Entry view

struct OverdueWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: OverdueEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(snapshot: entry.snapshot)
            case .systemMedium:
                MediumWidgetView(snapshot: entry.snapshot)
            default:
                SmallWidgetView(snapshot: entry.snapshot)
            }
        }
        .containerBackground(Color(uiColor: resolvedBackgroundColor), for: .widget)
        .applyAppTheme(entry.snapshot.themeOverride)
    }

    /// Resolves UIColor.systemBackground against either a forced trait
    /// collection (when the user picked "dark" or "light" in-app) or
    /// leaves it dynamic (when they chose "system"). Explicit resolution
    /// is required because `.containerBackground(_:for:)` captures its
    /// ShapeStyle outside the view's environment — `.fill.tertiary` and
    /// friends won't flip in response to an `.environment(\.colorScheme)`
    /// override applied higher up the widget's view tree.
    private var resolvedBackgroundColor: UIColor {
        switch entry.snapshot.themeOverride {
        case "dark":
            return UIColor.systemBackground.resolvedColor(
                with: UITraitCollection(userInterfaceStyle: .dark)
            )
        case "light":
            return UIColor.systemBackground.resolvedColor(
                with: UITraitCollection(userInterfaceStyle: .light)
            )
        default:
            return UIColor.systemBackground
        }
    }
}

private extension View {
    /// Honors the app's Theme setting ("dark"/"light"/"system") from
    /// AppSettings. Widgets default to following the system — this
    /// modifier only overrides when the user picked a specific scheme.
    @ViewBuilder
    func applyAppTheme(_ theme: String?) -> some View {
        switch theme {
        case "dark":
            self.environment(\.colorScheme, .dark)
        case "light":
            self.environment(\.colorScheme, .light)
        default:
            self
        }
    }
}

// MARK: - Small widget

struct SmallWidgetView: View {
    let snapshot: WidgetDataProvider.Snapshot

    var body: some View {
        Group {
            if let first = snapshot.featured.first {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
                        if snapshot.overdueCount > 0 {
                            Text("\(snapshot.overdueCount)")
                                .font(.system(size: 40, weight: .semibold, design: .rounded))
                                .foregroundStyle(.red)
                            Spacer()
                            Text("overdue")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.top, 12)
                        } else {
                            Text("\(snapshot.featured.count)")
                                .font(.system(size: 40, weight: .semibold, design: .rounded))
                                .foregroundStyle(.orange)
                            Spacer()
                            Text("due soon")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.top, 12)
                        }
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 8) {
                        WidgetAvatarView(
                            initials: first.initials,
                            colorHex: first.avatarColorHex,
                            statusRingColor: first.status.ringColor,
                            diameter: 32
                        )
                        VStack(alignment: .leading, spacing: 0) {
                            Text(first.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Text(first.status.shortSubtitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                EmptyStateView(hasTrackedPeople: snapshot.hasTrackedPeople)
            }
        }
        .widgetURL(DeepLinkRoute.overdue.url())
    }
}

// MARK: - Medium widget

struct MediumWidgetView: View {
    let snapshot: WidgetDataProvider.Snapshot

    var body: some View {
        if snapshot.featured.isEmpty {
            EmptyStateView(hasTrackedPeople: snapshot.hasTrackedPeople)
                .widgetURL(DeepLinkRoute.overdue.url())
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(headerText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                VStack(spacing: 8) {
                    ForEach(snapshot.featured, id: \.id) { person in
                        Link(destination: DeepLinkRoute.person(person.id).url()) {
                            personRow(person)
                        }
                    }
                    if snapshot.featured.count < 3 {
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var headerText: String {
        let overdue = snapshot.overdueCount
        let dueSoon = snapshot.featured.count - overdue
        switch (overdue, dueSoon) {
        case (0, _): return "\(dueSoon) due soon"
        case (_, 0): return "\(overdue) overdue"
        default: return "\(overdue) overdue · \(dueSoon) due soon"
        }
    }

    private func personRow(_ person: OverduePerson) -> some View {
        HStack(spacing: 10) {
            WidgetAvatarView(
                initials: person.initials,
                colorHex: person.avatarColorHex,
                statusRingColor: person.status.ringColor,
                diameter: 32
            )
            VStack(alignment: .leading, spacing: 1) {
                Text(person.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(person.status.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            GroupChip(name: person.groupName, colorHex: person.groupColorHex)
        }
        .contentShape(Rectangle())
    }
}

private struct GroupChip: View {
    let name: String
    let colorHex: String?

    var body: some View {
        let tint = (colorHex.flatMap(Color.init(hex:))) ?? .gray
        Text(name.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.15), in: Capsule())
            .lineLimit(1)
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    let hasTrackedPeople: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: hasTrackedPeople ? "leaf.fill" : "person.crop.circle.badge.plus")
                .font(.title)
                .foregroundStyle(hasTrackedPeople ? .green : .secondary)
            Text(hasTrackedPeople ? "All caught up" : "Add someone to track")
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Widget

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
        .description("People from a selected group who are overdue for a reach-out.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    OverdueWidget()
} timeline: {
    OverdueEntry(date: .now, configuration: OverdueWidgetConfigurationIntent(), snapshot: .placeholder)
    OverdueEntry(date: .now, configuration: OverdueWidgetConfigurationIntent(), snapshot: .allCaughtUp)
    OverdueEntry(date: .now, configuration: OverdueWidgetConfigurationIntent(), snapshot: .empty)
}

#Preview(as: .systemMedium) {
    OverdueWidget()
} timeline: {
    OverdueEntry(date: .now, configuration: OverdueWidgetConfigurationIntent(), snapshot: .placeholder)
    OverdueEntry(date: .now, configuration: OverdueWidgetConfigurationIntent(), snapshot: .allCaughtUp)
}
