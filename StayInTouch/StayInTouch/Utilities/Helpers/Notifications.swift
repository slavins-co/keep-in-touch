//
//  Notifications.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

extension Notification.Name {
    static let personDidChange = Notification.Name("personDidChange")
    static let settingsDidChange = Notification.Name("settingsDidChange")
    static let contactsDidSync = Notification.Name("contactsDidSync")
    static let coreDataMigrationFailed = Notification.Name("coreDataMigrationFailed")
}
