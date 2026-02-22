//
//  ContactCard.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

struct ContactCard: View {
    let person: Person
    let groupName: String
    let tags: [Tag]
    let status: SLAStatus
    let daysOverdue: Int
    let metadataText: String

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text(person.displayName)
                    .font(DS.Typography.contactName)
                    .lineLimit(1)
                Spacer()
                StatusIndicator(status: status, daysOverdue: daysOverdue)
            }

            Text(metadataText)
                .font(DS.Typography.metadata)
                .foregroundStyle(DS.Colors.secondaryText)
                .lineLimit(1)

            if !tags.isEmpty {
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(tags, id: \.id) { tag in
                        TagPill(tag: tag)
                    }
                }
            }
        }
        .padding(.vertical, DS.Spacing.md)
        .contentShape(Rectangle())
    }
}
