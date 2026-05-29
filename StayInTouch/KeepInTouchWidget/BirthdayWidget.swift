//
//  BirthdayWidget.swift
//  KeepInTouchWidget
//
//  Dedicated home-screen widget (small + medium) surfacing the next
//  upcoming birthdays with day countdowns (#329). Reads only the App Group
//  Core Data store + birthday cache via WidgetDataProvider — no Contacts
//  access in the extension. Shares the next-local-midnight refresh policy
//  so "tomorrow" rolls to "today" at midnight.
//

import SwiftUI
import WidgetKit

// MARK: - Entry

struct BirthdayEntry: TimelineEntry {
    let date: Date
    let birthdays: [BirthdaySummary]
    let themeOverride: String?

    static let placeholder = BirthdayEntry(
        date: Date(),
        birthdays: [
            BirthdaySummary(id: UUID(), displayName: "Mom", nickname: nil, initials: "M", avatarColorHex: "#A78BFA", daysUntil: 1, nextOccurrence: Date()),
            BirthdaySummary(id: UUID(), displayName: "Alex Carter", nickname: nil, initials: "AC", avatarColorHex: "#FF6B6B", daysUntil: 3, nextOccurrence: Date()),
            BirthdaySummary(id: UUID(), displayName: "Sam Park", nickname: "Sam", initials: "SP", avatarColorHex: "#4ECDC4", daysUntil: 6, nextOccurrence: Date()),
        ],
        themeOverride: nil
    )
}

// MARK: - Timeline provider

struct BirthdayTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> BirthdayEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (BirthdayEntry) -> Void) {
        completion(loadEntry(now: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BirthdayEntry>) -> Void) {
        let now = Date()
        let midnight = WidgetDataProvider.nextLocalMidnight(after: now)
        let entries = [loadEntry(now: now), loadEntry(now: midnight)]
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }

    private func loadEntry(now: Date) -> BirthdayEntry {
        let loaded = WidgetDataProvider.loadBirthdays(now: now, limit: WidgetDataProvider.birthdayFetchLimit)
        return BirthdayEntry(date: now, birthdays: loaded.birthdays, themeOverride: loaded.theme)
    }
}

// MARK: - Entry view

struct BirthdayWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: BirthdayEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                BirthdaySmallView(birthdays: entry.birthdays)
            case .systemMedium:
                BirthdayMediumView(birthdays: entry.birthdays)
            default:
                BirthdaySmallView(birthdays: entry.birthdays)
            }
        }
        .widgetAppTheme(entry.themeOverride)
    }
}

// MARK: - Small

struct BirthdaySmallView: View {
    let birthdays: [BirthdaySummary]

    var body: some View {
        if let cohort = WidgetDataProvider.soonestBirthdayCohort(from: birthdays) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Image(systemName: "birthday.cake.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(BrandColors.heroAccentGreen)
                    Spacer()
                    Text(cohort.primary.countdownLabel.lowercased())
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                }
                Spacer(minLength: 0)
                // Avatars on their own line, then the name full-width below, so
                // long names ("Daniel +2") aren't squeezed by the avatar stack
                // and the vertical space gets used.
                BirthdayCohortAvatars(cohort: cohort, diameter: 40)
                    .padding(.bottom, 6)
                Text(cohort.smallWidgetName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("birthday")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .widgetURL(cohort.tapURL)
        } else {
            BirthdayEmptyView()
        }
    }
}

// MARK: - Medium

struct BirthdayMediumView: View {
    let birthdays: [BirthdaySummary]

    private static let maxRows = 3
    private var rows: [BirthdaySummary] { Array(birthdays.prefix(Self.maxRows)) }
    private var overflow: Int { max(0, birthdays.count - Self.maxRows) }

    var body: some View {
        if rows.isEmpty {
            BirthdayEmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "birthday.cake.fill")
                        .font(.caption)
                        .foregroundStyle(BrandColors.heroAccentGreen)
                    Text("Upcoming Birthdays")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                VStack(spacing: 8) {
                    ForEach(rows, id: \.id) { birthday in
                        Link(destination: DeepLinkRoute.person(birthday.id).url()) {
                            row(birthday)
                        }
                    }
                    if overflow > 0 {
                        Text("+\(overflow) more")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 40)  // align under names, past the avatar
                    } else if rows.count < Self.maxRows {
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func row(_ birthday: BirthdaySummary) -> some View {
        HStack(spacing: 10) {
            WidgetAvatarView(
                initials: birthday.initials,
                colorHex: birthday.avatarColorHex,
                statusRingColor: BrandColors.heroAccentGreen,
                diameter: 30
            )
            Text(birthday.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(birthday.countdownLabel)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Empty state

struct BirthdayEmptyView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "birthday.cake")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("No birthdays this week")
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(DeepLinkRoute.overdue.url())
    }
}

// MARK: - Widget

struct BirthdayWidget: Widget {
    let kind: String = "BirthdayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BirthdayTimelineProvider()) { entry in
            BirthdayWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Upcoming Birthdays")
        .description("The next birthdays among the people you track, with day countdowns.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    BirthdayWidget()
} timeline: {
    BirthdayEntry.placeholder
    BirthdayEntry(date: Date(), birthdays: [], themeOverride: nil)
}

#Preview(as: .systemMedium) {
    BirthdayWidget()
} timeline: {
    BirthdayEntry.placeholder
    BirthdayEntry(date: Date(), birthdays: [], themeOverride: nil)
}
