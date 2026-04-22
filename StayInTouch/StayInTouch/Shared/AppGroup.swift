//
//  AppGroup.swift
//  KeepInTouch
//
//  Shared across the app and widget extension. Exposes the App Group
//  identifier and a helper for resolving the shared container URL.
//

import Foundation

enum AppGroup {
    static let identifier = "group.slavins.co.KeepInTouch"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static let coreDataStoreFilename = "StayInTouch.sqlite"

    static var coreDataStoreURL: URL? {
        containerURL?.appendingPathComponent(coreDataStoreFilename)
    }
}
