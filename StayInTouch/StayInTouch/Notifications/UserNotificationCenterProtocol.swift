//
//  UserNotificationCenterProtocol.swift
//  KeepInTouch
//

import UserNotifications

// Sendable so concrete implementations can be captured by Swift concurrency
// constructs (TaskGroup, async let). `UNUserNotificationCenter` is documented
// thread-safe; `MockUserNotificationCenter` is `@unchecked Sendable` with an
// internal lock guarding all mutable state.
protocol UserNotificationCenterProtocol: Sendable {
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>)
    func add(_ request: UNNotificationRequest) async throws
    func setBadgeCount(_ newBadgeCount: Int) async throws
    func removeAllPendingNotificationRequests()
}

extension UNUserNotificationCenter: UserNotificationCenterProtocol {}
