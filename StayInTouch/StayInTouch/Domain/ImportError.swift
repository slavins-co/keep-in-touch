//
//  ImportError.swift
//  KeepInTouch
//
//  Created by Claude Code on 3/10/26.
//

import Foundation

/// Typed errors thrown during JSON import operations.
enum ImportError: Error {
    case malformedJSON(details: String)
    case duplicateConflict(personId: UUID)
    case fileAccessDenied
    case parseError(underlying: Error)

    var userMessage: String {
        switch self {
        case .malformedJSON:
            return "The file couldn't be read — invalid format."
        case .duplicateConflict:
            return "Some contacts already exist and were skipped."
        case .fileAccessDenied:
            return "Couldn't access the file. Please try again."
        case .parseError:
            return "The file couldn't be parsed. Please check the format."
        }
    }
}
