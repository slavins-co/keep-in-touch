//
//  ContactCard.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

struct ContactCard: View {
    let person: Person
    let frequencyName: String
    let tags: [Tag]
    let status: ContactStatus
    let daysOverdue: Int
    let timeAgo: String
    let lastMethod: TouchMethod?

    var body: some View {
        HStack(alignment: .center, spacing: DS.Spacing.md) {
            ContactPhotoView(
                cnIdentifier: person.cnIdentifier,
                displayName: person.displayName,
                size: 36
            )

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                // Row 1: Name + inline tags + status
                HStack(spacing: DS.Spacing.sm) {
                Text(person.displayName)
                    .font(DS.Typography.contactName)
                    .lineLimit(1)
                    .layoutPriority(1)

                if !tags.isEmpty {
                    HStack(spacing: DS.Spacing.xs) {
                        ForEach(tags.prefix(2), id: \.id) { tag in
                            TagPill(tag: tag)
                        }
                        if tags.count > 2 {
                            Text("+\(tags.count - 2)")
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.secondaryText)
                        }
                    }
                    .lineLimit(1)
                }

                Spacer(minLength: DS.Spacing.xs)
                StatusIndicator(status: status, daysOverdue: daysOverdue)
            }

                // Row 2: Icon-labeled metadata
                metadataRow
            }
        }
        .padding(.vertical, DS.Spacing.md)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var metadataRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            Label(timeAgo, systemImage: "clock")

            if let method = lastMethod {
                Text("\u{00B7}").foregroundStyle(DS.Colors.tertiaryText)
                Label(method.rawValue, systemImage: DS.touchMethodIcon(method))
            }

            Text("\u{00B7}").foregroundStyle(DS.Colors.tertiaryText)
            Label(frequencyName, systemImage: "arrow.triangle.2.circlepath")
        }
        .font(DS.Typography.metadata)
        .foregroundStyle(DS.Colors.secondaryText)
        .lineLimit(1)
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        var parts: [String] = ["Contact \(person.displayName)"]

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

        parts.append("\(frequencyName) frequency")
        parts.append("tap to view details")

        return parts.joined(separator: ", ")
    }
}
