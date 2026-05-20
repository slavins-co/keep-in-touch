//
//  SelectedAvatarChips.swift
//  KeepInTouch
//

import SwiftUI

/// Horizontal scrolling row of selected avatars with an X-to-remove
/// affordance. Shown at the top of the bulk-log modal so users can
/// correct mistakes without bouncing back to the picker.
struct SelectedAvatarChips: View {
    let people: [Person]
    let onRemove: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.md) {
                ForEach(people) { person in
                    chip(for: person)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
        }
        .background(DS.Colors.secondaryBackground)
    }

    private func chip(for person: Person) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            ZStack(alignment: .topTrailing) {
                ContactPhotoView(
                    cnIdentifier: person.cnIdentifier,
                    displayName: person.displayName,
                    avatarColor: person.avatarColor,
                    size: 44
                )

                Button {
                    onRemove(person.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white, DS.Colors.destructive)
                        .background(Circle().fill(.white).padding(2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(person.displayName) from selection")
                .offset(x: 6, y: -6)
            }
            .frame(width: 50, height: 50)

            Text(person.displayName.split(separator: " ").first.map(String.init) ?? person.displayName)
                .font(DS.Typography.metadata)
                .foregroundStyle(DS.Colors.secondaryText)
                .lineLimit(1)
                .frame(maxWidth: 70)
        }
    }
}
