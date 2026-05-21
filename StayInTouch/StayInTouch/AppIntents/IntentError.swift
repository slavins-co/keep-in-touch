//
//  IntentError.swift
//  KeepInTouch
//

import AppIntents
import Foundation

enum IntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case personNotFound
    case saveFailed
    case containerUnavailable

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .personNotFound:
            return "That contact is no longer in Keep In Touch. Edit this shortcut to pick another."
        case .saveFailed:
            return "Couldn't save the connection. Please try again."
        case .containerUnavailable:
            return "Open Keep In Touch once, then try this shortcut again."
        }
    }
}
