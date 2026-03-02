//
//  AppLogger.swift
//  KeepInTouch
//
//  Created by Claude Code on 2/3/26.
//

import Foundation
import os

/// Centralized logging utility for the Keep In Touch app
final class AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.keepintouch.app"

    // Category-specific loggers
    static let coreData = os.Logger(subsystem: subsystem, category: "CoreData")
    static let notifications = os.Logger(subsystem: subsystem, category: "Notifications")
    static let contacts = os.Logger(subsystem: subsystem, category: "Contacts")
    static let viewModel = os.Logger(subsystem: subsystem, category: "ViewModel")
    static let repository = os.Logger(subsystem: subsystem, category: "Repository")
    static let general = os.Logger(subsystem: subsystem, category: "General")

    /// Log an error with context
    static func logError(_ error: Error, category: os.Logger, context: String) {
        category.error("[\(context)] Error: \(error.localizedDescription)")
    }

    /// Log a warning
    static func logWarning(_ message: String, category: os.Logger) {
        category.warning("\(message)")
    }

    /// Log info
    static func logInfo(_ message: String, category: os.Logger) {
        category.info("\(message)")
    }

    /// Log debug information (only in debug builds)
    static func logDebug(_ message: String, category: os.Logger) {
        #if DEBUG
        category.debug("\(message)")
        #endif
    }
}
