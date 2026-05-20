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
            return "I couldn't find that contact in Keep In Touch."
        case .saveFailed:
            return "Couldn't save the connection. Please try again."
        case .containerUnavailable:
            return "Open Keep In Touch once, then try this shortcut again."
        }
    }
}
