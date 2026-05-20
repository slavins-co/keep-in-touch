//
//  RecentGroup.swift
//  KeepInTouch
//

import Foundation

/// A recently-logged bulk-touch group. Persisted as a small UserDefaults
/// payload so users can re-select frequent circles (dinner crew, hiking
/// buddies) without rebuilding the selection each time.
struct RecentGroup: Identifiable, Equatable, Codable {
    let id: UUID
    var personIds: [UUID]
    var createdAt: Date
}
