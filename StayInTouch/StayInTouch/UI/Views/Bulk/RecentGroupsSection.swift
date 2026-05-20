//
//  RecentGroupsSection.swift
//  KeepInTouch
//

import SwiftUI

/// Horizontally scrolling row of recent group selections shown at the
/// top of any picker while select mode is active. Tapping a chip fills
/// the selection in one tap — the seed for "persistent named groups"
/// down the road (#293 v2).
struct RecentGroupsSection: View {
    let groups: [RecentGroup]
    let peopleById: [UUID: Person]
    let onSelect: ([UUID]) -> Void

    var body: some View {
        if visibleGroups.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("RECENT")
                    .font(DS.Typography.sectionHeaderMono)
                    .foregroundStyle(DS.Colors.secondaryText)
                    .padding(.horizontal, DS.Spacing.lg)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.md) {
                        ForEach(visibleGroups) { group in
                            chip(for: group)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                }
            }
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Colors.secondaryBackground)
        }
    }

    /// Filter out any RecentGroup whose members no longer all exist —
    /// surfacing a chip that selects ghost UUIDs would just produce a
    /// silently shorter selection.
    private var visibleGroups: [RecentGroup] {
        groups.filter { group in
            !group.personIds.isEmpty &&
            group.personIds.allSatisfy { peopleById[$0] != nil }
        }
    }

    private func chip(for group: RecentGroup) -> some View {
        let members = group.personIds.compactMap { peopleById[$0] }
        let label = members.prefix(3).map { firstName($0.displayName) }.joined(separator: ", ")
        let suffix = members.count > 3 ? " +\(members.count - 3)" : ""

        return Button {
            onSelect(group.personIds)
            Haptics.medium()
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                stackedAvatars(members: Array(members.prefix(3)))
                Text("\(label)\(suffix)")
                    .font(DS.Typography.metadata)
                    .foregroundStyle(DS.Colors.primaryText)
                    .lineLimit(1)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Colors.pageBg)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(DS.Colors.separator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Recent group: \(members.map(\.displayName).joined(separator: ", "))")
        .accessibilityHint("Fills selection with this group")
    }

    private func stackedAvatars(members: [Person]) -> some View {
        HStack(spacing: -10) {
            ForEach(members) { person in
                ContactPhotoView(
                    cnIdentifier: person.cnIdentifier,
                    displayName: person.displayName,
                    avatarColor: person.avatarColor,
                    size: 24
                )
                .overlay(Circle().stroke(DS.Colors.pageBg, lineWidth: 2))
            }
        }
    }

    private func firstName(_ name: String) -> String {
        name.split(separator: " ").first.map(String.init) ?? name
    }
}
