//
//  AnalyticsService.swift
//  StayInTouch
//

import TelemetryDeck

enum AnalyticsService {
    private static var isInitialized = false

    static func initialize() {
        guard !isInitialized else { return }
        let config = TelemetryDeck.Config(appID: "C41D550D-50EA-40BC-9605-584654EE2D5B")
        TelemetryDeck.initialize(config: config)
        isInitialized = true
    }

    static func track(_ signal: String, parameters: [String: String] = [:]) {
        guard isEnabled else { return }
        if !isInitialized {
            initialize()
        }
        TelemetryDeck.signal(signal, parameters: parameters)
    }

    private static var isEnabled: Bool {
        let repo = CoreDataAppSettingsRepository(context: CoreDataStack.shared.viewContext)
        return repo.fetch()?.analyticsEnabled ?? true
    }
}
