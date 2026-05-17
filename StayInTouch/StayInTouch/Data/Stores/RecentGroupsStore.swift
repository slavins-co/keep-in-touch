//
//  RecentGroupsStore.swift
//  KeepInTouch
//

import Foundation

/// UserDefaults-backed history of recently bulk-logged groups. Last 3
/// distinct selections (dedupe by `Set(personIds)`) are surfaced at the
/// top of the bulk-log picker for one-tap reselection.
///
/// Decode failures are swallowed — the consequence is "no Recent
/// section" which is harmless. Encode failures are logged but not
/// surfaced; the user already saw their bulk-log succeed.
final class RecentGroupsStore {
    static let capacity = 3
    private static let storageKey = "bulkLog.recentGroups.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [RecentGroup] {
        guard let data = defaults.data(forKey: Self.storageKey) else { return [] }
        do {
            return try JSONDecoder().decode([RecentGroup].self, from: data)
        } catch {
            AppLogger.logError(error, category: AppLogger.general, context: "RecentGroupsStore.load")
            return []
        }
    }

    /// Append a new group, dedupe by membership set, cap at `capacity`.
    /// Order: most recent first.
    func append(personIds: [UUID], now: Date = Date()) {
        guard !personIds.isEmpty else { return }
        let newSet = Set(personIds)

        var current = load().filter { Set($0.personIds) != newSet }
        let entry = RecentGroup(id: UUID(), personIds: personIds, createdAt: now)
        current.insert(entry, at: 0)
        if current.count > Self.capacity {
            current = Array(current.prefix(Self.capacity))
        }
        persist(current)
    }

    func clear() {
        defaults.removeObject(forKey: Self.storageKey)
    }

    private func persist(_ groups: [RecentGroup]) {
        do {
            let data = try JSONEncoder().encode(groups)
            defaults.set(data, forKey: Self.storageKey)
        } catch {
            AppLogger.logError(error, category: AppLogger.general, context: "RecentGroupsStore.persist")
        }
    }
}
