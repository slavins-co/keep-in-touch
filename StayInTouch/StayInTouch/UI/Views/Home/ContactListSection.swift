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
    let cadencesById: [UUID: Cadence]
    let groupsById: [UUID: Group]
    let statusForPerson: (Person) -> ContactStatus
    let daysOverdueForPerson: (Person) -> Int
    let timeAgoForPerson: (Person) -> String
    let selectPerson: (Person) -> Void
    /// Shared select-mode coordinator. When `coordinator.isSelectMode` is
    /// true, rows render with a leading checkmark and taps toggle
    /// selection instead of opening the detail.
    @ObservedObject var coordinator: SelectionCoordinator

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Section {
            if !isCollapsed {
                ForEach(Array(people.enumerated()), id: \.element.id) { index, person in
                    let frequencyName = cadencesById[person.cadenceId]?.name ?? "Frequency"
                    let personGroups = person.groupIds.compactMap { groupsById[$0] }
                    let inSelectMode = coordinator.isSelectMode

                    Button {
                        if inSelectMode {
                            coordinator.toggleWithHaptic(person.id)
                        } else {
                            selectPerson(person)
                        }
                    } label: {
                        ContactCard(
                            person: person,
                            frequencyName: frequencyName,
                            status: statusForPerson(person),
                            daysOverdue: daysOverdueForPerson(person),
                            timeAgo: timeAgoForPerson(person),
                            lastMethod: person.lastTouchMethod,
                            groups: personGroups,
                            isSelected: inSelectMode ? coordinator.contains(person.id) : nil
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(inSelectMode
                                       ? "Toggles selection"
                                       : "Opens contact details")
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                            if !coordinator.isSelectMode {
                                coordinator.enter(origin: .home, preselect: person.id)
                            }
                        }
                    )

                    if index < people.count - 1 {
                        Rectangle()
                            .fill(DS.Colors.rowSeparator)
                            .frame(height: 1)
                            .padding(.leading, 64)
                            .accessibilityHidden(true)
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
                    .tracking(DS.Spacing.sectionHeaderTracking(scheme: colorScheme))
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
                    .fill(DS.Colors.rowSeparator)
                    .frame(height: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(people.count) contacts")
        .accessibilityHint(isCollapsed ? "Expands section" : "Collapses section")
    }
}
