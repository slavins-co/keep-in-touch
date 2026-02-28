//
//  ContactListSection.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

struct ContactListSection: View {
    let title: String
    let colorHex: String
    let people: [Person]
    let isCollapsed: Bool
    let onToggle: () -> Void
    let groupsById: [UUID: Group]
    let tagsById: [UUID: Tag]
    let statusForPerson: (Person) -> ContactStatus
    let daysOverdueForPerson: (Person) -> Int
    let timeAgoForPerson: (Person) -> String

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    Circle()
                        .fill(Color(hex: colorHex))
                        .frame(width: 8, height: 8)
                    Text(title)
                        .font(DS.Typography.sectionHeader)
                        .foregroundStyle(DS.Colors.primaryText)
                    Text("\(people.count)")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                        .foregroundStyle(DS.Colors.secondaryText)
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title), \(people.count) contacts")
            .accessibilityHint(isCollapsed ? "Expands section" : "Collapses section")

            if !isCollapsed {
                VStack(spacing: 0) {
                    ForEach(Array(people.enumerated()), id: \.element.id) { index, person in
                        let frequencyName = groupsById[person.groupId]?.name ?? "Frequency"
                        let tags = person.tagIds.compactMap { tagsById[$0] }
                        NavigationLink {
                            PersonDetailView(person: person)
                        } label: {
                            ContactCard(
                                person: person,
                                frequencyName: frequencyName,
                                tags: tags,
                                status: statusForPerson(person),
                                daysOverdue: daysOverdueForPerson(person),
                                timeAgo: timeAgoForPerson(person),
                                lastMethod: person.lastTouchMethod
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens contact details")

                        if index < people.count - 1 {
                            SubtleDivider()
                                .padding(.leading, DS.Spacing.lg)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
    }
}
