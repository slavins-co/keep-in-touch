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

    // E6 added concurrent `notificationCenter.add` calls via TaskGroup
    // inside the scheduler. Real `UNUserNotificationCenter` is documented
    // thread-safe; this mock must be too. Guard all mutable state behind
    // a lock so parallel `add(_:)` calls cannot race on `Array.append`.
    private let lock = NSLock()
    private var _addedRequests: [UNNotificationRequest] = []
    private var _categoriesSet: Set<UNNotificationCategory> = []
    private var _badgeCounts: [Int] = []
    private var _removeAllCallCount = 0
    private var _operations: [Operation] = []

    var addedRequests: [UNNotificationRequest] {
        get { lock.lock(); defer { lock.unlock() }; return _addedRequests }
        set { lock.lock(); defer { lock.unlock() }; _addedRequests = newValue }
    }
    var categoriesSet: Set<UNNotificationCategory> {
        get { lock.lock(); defer { lock.unlock() }; return _categoriesSet }
    }
    var badgeCounts: [Int] {
        get { lock.lock(); defer { lock.unlock() }; return _badgeCounts }
    }
    var removeAllCallCount: Int {
        get { lock.lock(); defer { lock.unlock() }; return _removeAllCallCount }
    }
    var operations: [Operation] {
        get { lock.lock(); defer { lock.unlock() }; return _operations }
    }

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        lock.lock(); defer { lock.unlock() }
        _categoriesSet = categories
        _operations.append(.setCategories)
    }

    func add(_ request: UNNotificationRequest) async throws {
        // Swift 6 forbids NSLock.lock()/unlock() in async contexts (deadlock
        // risk across suspension); use scoped withLock instead.
        lock.withLock {
            _addedRequests.append(request)
            _operations.append(.add(request))
        }
    }

    func setBadgeCount(_ newBadgeCount: Int) async throws {
        lock.withLock {
            _badgeCounts.append(newBadgeCount)
            _operations.append(.setBadge(newBadgeCount))
        }
    }

    func removeAllPendingNotificationRequests() {
        lock.lock(); defer { lock.unlock() }
        _removeAllCallCount += 1
        _addedRequests = []
        _operations.append(.removeAll)
    }
}
