//
//  PreferredMessenger.swift
//  KeepInTouch
//

import Foundation

/// User's preferred messenger app for the Message quick action, per contact.
/// Stored on `Person.preferredMessenger`. `nil` means "use app default" (iMessage in v1).
enum PreferredMessenger: String, CaseIterable, Codable {
    case iMessage
    case whatsapp
    case signal

    /// Human-readable name for menus and labels.
    var displayName: String {
        switch self {
        case .iMessage: return "iMessage"
        case .whatsapp: return "WhatsApp"
        case .signal: return "Signal"
        }
    }

    /// SF Symbol used in pickers and indicators.
    var iconName: String {
        switch self {
        case .iMessage: return "message.fill"
        case .whatsapp: return "bubble.left.and.bubble.right.fill"
        case .signal: return "lock.message.fill"
        }
    }

    /// TouchMethod recorded when a touch is auto-logged via this messenger.
    var touchMethod: TouchMethod {
        switch self {
        case .iMessage: return .text
        case .whatsapp: return .whatsapp
        case .signal: return .signal
        }
    }

    /// VoiceOver accessibility hint describing the outcome of tapping the
    /// Message button when this messenger is the resolved default. Avoids
    /// the naive `"\(displayName)s this contact"` formula which produces
    /// ungrammatical results like "WhatsApps this contact".
    var actionHint: String {
        switch self {
        case .iMessage: return "Sends a message to this contact"
        case .whatsapp: return "Opens WhatsApp chat with this contact"
        case .signal: return "Opens Signal chat with this contact"
        }
    }
}
