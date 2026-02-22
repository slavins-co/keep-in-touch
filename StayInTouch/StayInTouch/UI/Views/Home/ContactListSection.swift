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
    let statusForPerson: (Person) -> SLAStatus
    let daysOverdueForPerson: (Person) -> Int
    let metadataTextForPerson: (Person) -> String

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    Text(title)
                        .font(DS.Typography.sectionHeader)
                        .foregroundStyle(Color(hex: colorHex))
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

            if !isCollapsed {
                VStack(spacing: 0) {
                    ForEach(Array(people.enumerated()), id: \.element.id) { index, person in
                        let groupName = groupsById[person.groupId]?.name ?? "Group"
                        let tags = person.tagIds.compactMap { tagsById[$0] }
                        NavigationLink {
                            PersonDetailView(person: person)
                        } label: {
                            ContactCard(
                                person: person,
                                groupName: groupName,
                                tags: tags,
                                status: statusForPerson(person),
                                daysOverdue: daysOverdueForPerson(person),
                                metadataText: metadataTextForPerson(person)
                            )
                        }
                        .buttonStyle(.plain)

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
