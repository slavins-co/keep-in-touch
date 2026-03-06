//
//  MockUserNotificationCenter.swift
//  KeepInTouchTests
//

import UserNotifications
@testable import StayInTouch

final class MockUserNotificationCenter: UserNotificationCenterProtocol, @unchecked Sendable {
    var addedRequests: [UNNotificationRequest] = []
    var categoriesSet: Set<UNNotificationCategory> = []
    var badgeCounts: [Int] = []
    var removeAllCallCount = 0

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        categoriesSet = categories
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }

    func setBadgeCount(_ newBadgeCount: Int) async throws {
        badgeCounts.append(newBadgeCount)
    }

    func removeAllPendingNotificationRequests() {
        removeAllCallCount += 1
        addedRequests = []
    }
}
