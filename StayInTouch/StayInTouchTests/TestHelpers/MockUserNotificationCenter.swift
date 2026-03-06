//
//  MockUserNotificationCenter.swift
//  KeepInTouchTests
//

import UserNotifications
@testable import StayInTouch

final class MockUserNotificationCenter: UserNotificationCenterProtocol, @unchecked Sendable {
    enum Operation {
        case removeAll
        case add(UNNotificationRequest)
        case setBadge(Int)
        case setCategories
    }

    var addedRequests: [UNNotificationRequest] = []
    var categoriesSet: Set<UNNotificationCategory> = []
    var badgeCounts: [Int] = []
    var removeAllCallCount = 0
    private(set) var operations: [Operation] = []

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        categoriesSet = categories
        operations.append(.setCategories)
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
        operations.append(.add(request))
    }

    func setBadgeCount(_ newBadgeCount: Int) async throws {
        badgeCounts.append(newBadgeCount)
        operations.append(.setBadge(newBadgeCount))
    }

    func removeAllPendingNotificationRequests() {
        removeAllCallCount += 1
        addedRequests = []
        operations.append(.removeAll)
    }
}
