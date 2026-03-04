//
//  ContactListSection.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

struct ContactListSection: View {
    let title: String
    let people: [Person]
    let isCollapsed: Bool
    let onToggle: () -> Void
    let groupsById: [UUID: Group]
    let statusForPerson: (Person) -> ContactStatus
    let daysOverdueForPerson: (Person) -> Int
    let timeAgoForPerson: (Person) -> String
    let selectPerson: (Person) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Section {
            if !isCollapsed {
                ForEach(Array(people.enumerated()), id: \.element.id) { index, person in
                    let frequencyName = groupsById[person.groupId]?.name ?? "Frequency"
                    Button {
                        selectPerson(person)
                    } label: {
                        ContactCard(
                            person: person,
                            frequencyName: frequencyName,
                            status: statusForPerson(person),
                            daysOverdue: daysOverdueForPerson(person),
                            timeAgo: timeAgoForPerson(person),
                            lastMethod: person.lastTouchMethod
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens contact details")

                    if index < people.count - 1 {
                        Rectangle()
                            .fill(Color(.systemGray6))
                            .frame(height: 1)
                            .padding(.leading, 64)
                    }
                }
                .transition(.opacity)
            }
        } header: {
            sectionHeader
        }
    }

    private var sectionHeader: some View {
        Button(action: onToggle) {
            HStack {
                Text("\(title.uppercased()) \u{00B7} \(people.count)")
                    .font(DS.Typography.sectionHeaderMono)
                    .tracking(colorScheme == .dark ? 2.2 : 1.65)
                    .foregroundStyle(Color(.secondaryLabel))
                Spacer()
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    .foregroundStyle(Color(.secondaryLabel))
                    .font(.caption)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Colors.pageBg)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(.systemGray6))
                    .frame(height: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(people.count) contacts")
        .accessibilityHint(isCollapsed ? "Expands section" : "Collapses section")
    }
}
