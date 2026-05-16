//
//  WhatsNewContent.swift
//  KeepInTouch
//
//  "What's New" plumbing — empty for v1. Future releases author cards in
//  `WhatsNewRegistry.contentByVersion` and `WhatsNewPresenter` mounts them
//  via the same `WalkthroughOverlayView` engine. Until then this is a no-op.
//

import Foundation

struct WhatsNewCardContent: Identifiable {
    let id: String
    let title: String
    let body: String
    let systemImage: String?
}

struct WhatsNewContent {
    /// Marketing version this content applies to (e.g., "0.5.0").
    let version: String
    let cards: [WhatsNewCardContent]
}

enum WhatsNewRegistry {
    /// Per-release card sequences. Add new entries here when shipping a
    /// release that should surface "What's New" cards on first launch.
    static let contentByVersion: [String: WhatsNewContent] = [:]
    // Future releases add entries like:
    // "0.5.0": WhatsNewContent(version: "0.5.0", cards: [
    //     WhatsNewCardContent(id: "0.5.0-widgets", title: "Lock Screen Widgets",
    //                         body: "Pin Keep In Touch counts to your Lock Screen.",
    //                         systemImage: "rectangle.stack.fill"),
    // ])

    static func content(for version: String) -> WhatsNewContent? {
        contentByVersion[version]
    }
}
