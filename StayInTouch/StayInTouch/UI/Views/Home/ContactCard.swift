//
//  ContactCard.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

struct ContactCard: View {
    let person: Person
    let frequencyName: String
    let status: ContactStatus
    let daysOverdue: Int
    let timeAgo: String
    let lastMethod: TouchMethod?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: DS.Spacing.cardPadding) {
            ContactPhotoView(
                cnIdentifier: person.cnIdentifier,
                displayName: person.displayName,
                size: 48
            )

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(person.displayName)
                    .font(DS.Typography.contactCardName)
                    .foregroundStyle(DS.Colors.primaryText)
                    .lineLimit(1)

                metadataRow
            }

            Spacer(minLength: DS.Spacing.xs)

            VStack(alignment: .trailing, spacing: DS.Spacing.sm) {
                groupBadge
                StatusIndicator(status: status, dotOnly: true)
            }
        }
        .padding(.vertical, colorScheme == .dark ? DS.Spacing.lg : DS.Spacing.cardPadding)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Metadata Row

    @ViewBuilder
    private var metadataRow: some View {
        if person.isPaused {
            Label("Paused", systemImage: "moon.fill")
                .font(DS.Typography.contactCardMeta)
                .foregroundStyle(Color(.tertiaryLabel))
        } else if let snoozed = person.snoozedUntil, snoozed > Date() {
            Text("Snoozed \u{00B7} \(frequencyName)")
                .font(DS.Typography.contactCardMeta)
                .foregroundStyle(DS.Colors.textMuted)
        } else {
            HStack(spacing: DS.Spacing.xs) {
                Text("\(timeAgo) \u{00B7} \(frequencyName)")
                    .font(DS.Typography.contactCardMeta)
                    .foregroundStyle(Color(.secondaryLabel))

                if person.customDueDate != nil {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
            .lineLimit(1)
        }
    }

    // MARK: - Group Badge

    private var groupBadge: some View {
        Text(frequencyName.uppercased())
            .font(DS.Typography.groupBadgeLabel)
            .foregroundStyle(DS.Colors.groupBadgeText)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(DS.Colors.groupBadgeBackground)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        var parts: [String] = ["Contact \(person.displayName)"]

        if person.isPaused {
            parts.append("paused")
        } else if let snoozed = person.snoozedUntil, snoozed > Date() {
            parts.append("snoozed")
        } else {
            switch status {
            case .overdue:
                parts.append(daysOverdue > 0 ? "overdue by \(daysOverdue) days" : "overdue")
            case .dueSoon:
                parts.append("due soon")
            case .onTrack:
                parts.append("on track")
            case .unknown:
                parts.append("no contact yet")
            }

            if status != .unknown {
                parts.append("last contacted \(timeAgo)")
            }

            if let method = lastMethod {
                parts.append("via \(method.rawValue)")
            }

            if person.customDueDate != nil {
                parts.append("has custom due date")
            }
        }

        parts.append("\(frequencyName) frequency")
        parts.append("tap to view details")

        return parts.joined(separator: ", ")
    }
}
