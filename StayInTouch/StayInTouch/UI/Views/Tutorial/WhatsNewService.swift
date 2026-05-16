//
//  WhatsNewService.swift
//  KeepInTouch
//
//  Compares the persisted `lastSeenAppVersion` against the current
//  marketing version. Returns any matching `WhatsNewContent` for the
//  app to surface, and stamps the current version so the same content
//  doesn't fire twice.
//
//  For v1, `WhatsNewRegistry` is empty so this always returns nil after
//  stamping the version.
//

import Foundation

@MainActor
enum WhatsNewService {
    /// Inspect persisted state and decide whether to present "What's New".
    /// Always writes through `lastSeenAppVersion = current` so the same
    /// content can't fire twice in a row.
    static func contentToPresent(
        repository: AppSettingsRepository,
        currentVersion: String = GeneratedVersion.marketing
    ) -> WhatsNewContent? {
        guard var settings = repository.fetch() else { return nil }
        let previous = settings.lastSeenAppVersion
        guard previous != currentVersion else { return nil }

        settings.lastSeenAppVersion = currentVersion
        try? repository.save(settings)

        // First launch on any version — don't show, just record.
        guard previous != nil else { return nil }

        return WhatsNewRegistry.content(for: currentVersion)
    }
}
