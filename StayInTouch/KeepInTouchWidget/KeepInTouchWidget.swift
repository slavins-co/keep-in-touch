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
        let filter = configuredFilter(configuration)
        let midnight = WidgetDataProvider.nextLocalMidnight(after: now)

        // Two entries: now, and the next local midnight (with its snapshot
        // computed as-of midnight so day-relative copy — "tomorrow" → "today",
        // daysOverdue increments, a birthday entering the window — rolls over
        // exactly at midnight). Reload after midnight to recompute the next day.
        let entries = [
            OverdueEntry(
                date: now,
                configuration: configuration,
                snapshot: WidgetDataProvider.loadSnapshot(now: now, groupFilter: filter)
            ),
            OverdueEntry(
                date: midnight,
                configuration: configuration,
                snapshot: WidgetDataProvider.loadSnapshot(now: midnight, groupFilter: filter)
            ),
        ]
        return Timeline(entries: entries, policy: .after(midnight))
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
        dueSoonCount: 1,
        featured: [
            OverduePerson(id: UUID(), displayName: "Alex Carter", nickname: nil, initials: "AC", avatarColorHex: "#FF6B6B", groupName: "Weekly", groupColorHex: "#4ECDC4", status: .overdue(daysOverdue: 5)),
            OverduePerson(id: UUID(), displayName: "Samantha Park", nickname: "Sam", initials: "SP", avatarColorHex: "#4ECDC4", groupName: "Monthly", groupColorHex: "#FFD166", status: .overdue(daysOverdue: 1)),
            OverduePerson(id: UUID(), displayName: "Jordan", nickname: nil, initials: "J", avatarColorHex: "#FFD166", groupName: "Quarterly", groupColorHex: "#A78BFA", status: .dueSoon(daysUntilDue: 2)),
        ],
        hasTrackedPeople: true,
        trackedCount: 8,
        themeOverride: nil,
        upcomingBirthdays: [
            BirthdaySummary(id: UUID(), displayName: "Mom", nickname: nil, initials: "M", avatarColorHex: "#A78BFA", daysUntil: 1, nextOccurrence: Date()),
        ],
        birthdaysFillWidget: true
    )

    static let empty = WidgetDataProvider.Snapshot(overdueCount: 0, dueSoonCount: 0, featured: [], hasTrackedPeople: false, trackedCount: 0, themeOverride: nil, upcomingBirthdays: [], birthdaysFillWidget: true)
    static let allCaughtUp = WidgetDataProvider.Snapshot(overdueCount: 0, dueSoonCount: 0, featured: [], hasTrackedPeople: true, trackedCount: 5, themeOverride: nil, upcomingBirthdays: [], birthdaysFillWidget: true)
}

extension WidgetPersonStatus {
    /// SwiftUI ring tint. Lives here (widget target) because `Color` is
    /// SwiftUI; the textual helpers are in `Shared/WidgetDataProvider.swift`
    /// so non-SwiftUI consumers (`AccessoryWidgetLogic`, tests) can reach them.
    var ringColor: Color {
        switch self {
        case .overdue: return .red
        case .dueSoon: return .orange
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

    /// The soonest upcoming birthday to surface, when the setting is on.
    private var upcomingBirthday: BirthdaySummary? {
        guard snapshot.birthdaysFillWidget else { return nil }
        return snapshot.upcomingBirthdays.first
    }

    var body: some View {
        Group {
            if let first = snapshot.featured.first {
                atRiskLayout(first)
                    .widgetURL(DeepLinkRoute.overdue.url())
            } else if let birthday = upcomingBirthday {
                birthdayLayout(birthday)
                    .widgetURL(DeepLinkRoute.person(birthday.id).url())
            } else {
                EmptyStateView(hasTrackedPeople: snapshot.hasTrackedPeople)
                    .widgetURL(DeepLinkRoute.overdue.url())
            }
        }
    }

    private func atRiskLayout(_ first: OverduePerson) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                if snapshot.overdueCount > 0 {
                    Text("\(snapshot.overdueCount)")
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .foregroundStyle(.red)
                    Spacer()
                    countLabelStack("overdue")
                } else {
                    Text("\(snapshot.dueSoonCount)")
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .foregroundStyle(.orange)
                    Spacer()
                    countLabelStack("due soon")
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
    }

    /// The count's trailing label, badged with a cake glyph when a birthday
    /// is within the window (the small widget can't list it, so the badge
    /// signals "tap through, a birthday is coming").
    private func countLabelStack(_ text: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            if upcomingBirthday != nil {
                Image(systemName: "birthday.cake.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(BrandColors.heroAccentGreen)
            }
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 12)
    }

    private func birthdayLayout(_ birthday: BirthdaySummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Image(systemName: "birthday.cake.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(BrandColors.heroAccentGreen)
                Spacer()
                Text("birthday")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                WidgetAvatarView(
                    initials: birthday.initials,
                    colorHex: birthday.avatarColorHex,
                    statusRingColor: BrandColors.heroAccentGreen,
                    diameter: 32
                )
                VStack(alignment: .leading, spacing: 0) {
                    Text(birthday.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text(birthday.countdownLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Medium widget

struct MediumWidgetView: View {
    let snapshot: WidgetDataProvider.Snapshot

    /// Birthdays that back-fill the empty rows below the at-risk list, gated
    /// by the user's setting. Capped to whatever row budget the at-risk list
    /// leaves free (total rows ≤ maxFeaturedPeople).
    private var birthdayRows: [BirthdaySummary] {
        guard snapshot.birthdaysFillWidget else { return [] }
        let freeRows = max(0, WidgetDataProvider.maxFeaturedPeople - snapshot.featured.count)
        return Array(snapshot.upcomingBirthdays.prefix(freeRows))
    }

    var body: some View {
        if snapshot.featured.isEmpty && birthdayRows.isEmpty {
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
                    ForEach(birthdayRows, id: \.id) { birthday in
                        Link(destination: DeepLinkRoute.person(birthday.id).url()) {
                            birthdayRow(birthday)
                        }
                    }
                    if snapshot.featured.count + birthdayRows.count < WidgetDataProvider.maxFeaturedPeople {
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var headerText: String {
        let overdue = snapshot.overdueCount
        let dueSoon = snapshot.dueSoonCount
        switch (overdue, dueSoon) {
        case (0, 0): return "Upcoming birthdays"
        case (0, _): return "\(dueSoon) due soon"
        case (_, 0): return "\(overdue) overdue"
        default: return "\(overdue) overdue · \(dueSoon) due soon"
        }
    }

    private func birthdayRow(_ birthday: BirthdaySummary) -> some View {
        HStack(spacing: 10) {
            WidgetAvatarView(
                initials: birthday.initials,
                colorHex: birthday.avatarColorHex,
                statusRingColor: BrandColors.heroAccentGreen,
                diameter: 32
            )
            VStack(alignment: .leading, spacing: 1) {
                Text(birthday.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("Birthday \(birthday.countdownLabel)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "birthday.cake.fill")
                .font(.system(size: 14))
                .foregroundStyle(BrandColors.heroAccentGreen)
        }
        .contentShape(Rectangle())
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
        let tint = colorHex.map(Color.init(hex:)) ?? .gray
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
            Image(systemName: hasTrackedPeople ? "hand.wave.fill" : "person.crop.circle.badge.plus")
                .font(.title)
                .foregroundStyle(hasTrackedPeople ? BrandColors.heroAccentGreen : .secondary)
            Text(hasTrackedPeople ? "You've reached out to everyone.\nWay to go!" : "Add someone to track")
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
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
