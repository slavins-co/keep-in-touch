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
}
