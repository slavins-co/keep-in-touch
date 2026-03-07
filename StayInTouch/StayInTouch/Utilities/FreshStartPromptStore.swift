//
//  FreshStartPromptStore.swift
//  KeepInTouch
//

import Foundation

struct FreshStartPromptStore {
    private let defaults: UserDefaults

    private enum Keys {
        static let lastDismissedAt = "freshStart.lastDismissedAt"
        static let lastAppOpenedAt = "freshStart.lastAppOpenedAt"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var lastDismissedAt: Date? {
        get { defaults.object(forKey: Keys.lastDismissedAt) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastDismissedAt) }
    }

    var lastAppOpenedAt: Date? {
        get { defaults.object(forKey: Keys.lastAppOpenedAt) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastAppOpenedAt) }
    }

    mutating func recordAppOpen() {
        lastAppOpenedAt = Date()
    }

    mutating func recordDismissal() {
        lastDismissedAt = Date()
    }
}
