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
        VStack(spacing: 8) {
            Button(action: onToggle) {
                HStack {
                    Circle()
                        .fill(Color(hex: colorHex))
                        .frame(width: 10, height: 10)
                    Text("\(title) (\(people.count))")
                        .font(.callout)
                    Spacer()
                    Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if !isCollapsed {
                VStack(spacing: 8) {
                    ForEach(people, id: \.id) { person in
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
                    }
                }
                .transition(.opacity)
            }
        }
    }
}
