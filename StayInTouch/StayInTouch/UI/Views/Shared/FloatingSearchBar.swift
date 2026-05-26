//
//  FloatingSearchBar.swift
//  KeepInTouch
//
//  Floating capsule-shaped search bar with a gradient fade-in above it.
//  Visually identical to the inline search bars previously duplicated in
//  `HomeView` and `ContactsListView` (audit finding Q5, issue #313).
//
//  Owns its own focus state so callers don't need to thread a
//  `FocusState` binding. If callers need to enforce input limits or
//  side-effects on each keystroke, they should wrap their text source
//  in a custom `Binding` whose `set` clamps/observes before forwarding.
//

import SwiftUI

struct FloatingSearchBar: View {
    @Binding var text: String
    var placeholder: LocalizedStringKey = "Search contacts..."
    /// Optional tutorial anchor ID applied to the inner search pill (matches
    /// the pre-extraction spotlight bounds in `HomeView`). Pass `nil` from
    /// callers that don't participate in the walkthrough (e.g. Contacts tab).
    var tutorialAnchorID: String? = nil

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [DS.Colors.pageBg.opacity(0), DS.Colors.pageBg],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 20)

            searchPill
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.lg)
                .frame(maxWidth: .infinity)
                .background(DS.Colors.pageBg)
        }
    }

    @ViewBuilder
    private var searchPill: some View {
        let pill = HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DS.Colors.searchBarIcon)
            TextField(
                placeholder,
                text: $text
            )
            .textFieldStyle(.plain)
            .focused($isSearchFocused)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DS.Colors.tertiaryText)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(DS.Colors.searchBarBackground)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(
                    isSearchFocused
                        ? DS.Colors.searchBarFocusRing
                        : DS.Colors.searchBarBorder,
                    lineWidth: isSearchFocused ? 2 : 1
                )
        )
        .shadow(
            color: DS.Colors.searchBarShadow,
            radius: 8,
            y: 2
        )

        if let anchorID = tutorialAnchorID {
            pill.tutorialAnchor(anchorID)
        } else {
            pill
        }
    }
}
