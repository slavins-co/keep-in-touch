//
//  UserNotificationCenterProtocol.swift
//  KeepInTouch
//

import UserNotifications

protocol UserNotificationCenterProtocol {
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>)
    func add(_ request: UNNotificationRequest) async throws
    func setBadgeCount(_ newBadgeCount: Int) async throws
    func removeAllPendingNotificationRequests()
}

extension UNUserNotificationCenter: UserNotificationCenterProtocol {}
