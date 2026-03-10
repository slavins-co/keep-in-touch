//
//  RepositoryError.swift
//  KeepInTouch
//
//  Created by Claude Code on 3/10/26.
//

import Foundation

/// Typed errors thrown by repository save and delete operations.
/// Wraps the underlying Core Data error with entity and context information.
enum RepositoryError: Error {
    case saveFailed(entity: String, underlying: Error)
    case deleteFailed(entity: String, id: UUID, underlying: Error)

    var userMessage: String {
        switch self {
        case .saveFailed:
            return "Couldn't save changes. Please try again."
        case .deleteFailed:
            return "Couldn't delete. Please try again."
        }
    }
}
