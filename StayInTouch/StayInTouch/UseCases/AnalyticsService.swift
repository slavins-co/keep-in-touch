//
//  AnalyticsService.swift
//  StayInTouch
//

import Foundation
import TelemetryDeck

enum AnalyticsService {
    private static let lock = NSLock()
    private static var _isInitialized = false
    private static var _isEnabled = true

    static func initialize() {
        lock.withLock {
            guard !_isInitialized else { return }
            let config = TelemetryDeck.Config(appID: "C41D550D-50EA-40BC-9605-584654EE2D5B")
            TelemetryDeck.initialize(config: config)
            // Read initial analytics setting from Core Data
            let repo = CoreDataAppSettingsRepository(context: CoreDataStack.shared.viewContext)
            _isEnabled = repo.fetch()?.analyticsEnabled ?? true
            _isInitialized = true
        }
    }

    static func track(_ signal: String, parameters: [String: String] = [:]) {
        lock.lock()
        let enabled = _isEnabled
        if !_isInitialized {
            lock.unlock()
            initialize()
        } else {
            lock.unlock()
        }
        guard enabled else { return }
        TelemetryDeck.signal(signal, parameters: parameters)
    }

    static func updateEnabled(_ enabled: Bool) {
        lock.withLock { _isEnabled = enabled }
    }
}
