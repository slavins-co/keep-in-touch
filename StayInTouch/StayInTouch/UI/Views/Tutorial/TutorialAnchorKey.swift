//
//  TutorialAnchorKey.swift
//  KeepInTouch
//
//  PreferenceKey that lets descendant views advertise their bounds to the
//  walkthrough overlay using stable string identifiers.
//

import SwiftUI

struct TutorialAnchorKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [String: Anchor<CGRect>],
        nextValue: () -> [String: Anchor<CGRect>]
    ) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Marks this view as a tutorial anchor target. The walkthrough overlay reads
    /// the view's bounds via `TutorialAnchorKey` and positions its spotlight cutout
    /// around it.
    func tutorialAnchor(_ id: String) -> some View {
        anchorPreference(
            key: TutorialAnchorKey.self,
            value: .bounds
        ) { [id: $0] }
    }

    /// Attaches a `.id(_:)` to a view ONLY when in tutorial preview mode, so the
    /// walkthrough can ask the surrounding `ScrollViewReader` to scroll to it
    /// without affecting normal-mode view identity.
    @ViewBuilder
    func tutorialScrollID(_ id: String, isPreview: Bool) -> some View {
        if isPreview {
            self.id(id)
        } else {
            self
        }
    }
}

extension Notification.Name {
    /// Posted by `WalkthroughCoordinator` when the current step changes inside
    /// the demo PersonDetail. The notification's `object` is the anchor ID
    /// (`String`) that the ScrollViewReader should scroll into view.
    static let tutorialScrollToAnchor = Notification.Name("tutorialScrollToAnchor")
}
