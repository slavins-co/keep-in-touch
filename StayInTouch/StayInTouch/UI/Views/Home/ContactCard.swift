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
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: person.avatarColor))
                    .frame(width: 44, height: 44)
                Text(person.initials)
                    .font(.callout)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(person.displayName)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(metadataText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if !tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.id) { tag in
                            Text(tag.name)
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color(hex: tag.colorHex))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            Spacer()

            VStack(spacing: 6) {
                if daysOverdue > 0 {
                    Text("+\(daysOverdue)d")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Circle()
                    .fill(statusColor())
                    .frame(width: 10, height: 10)

                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statusColor() -> Color {
        switch status {
        case .inSLA: return Color(hex: "34C759")
        case .dueSoon: return Color(hex: "FF9500")
        case .outOfSLA: return Color(hex: "FF3B30")
        case .unknown: return Color(hex: "8E8E93")
        }
    }
}
