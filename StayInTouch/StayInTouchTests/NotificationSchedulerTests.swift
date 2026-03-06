//
//  NotificationSchedulerTests.swift
//  KeepInTouchTests
//

import XCTest
@testable import StayInTouch

final class NotificationSchedulerTests: XCTestCase {

    private var mockNotificationCenter: MockUserNotificationCenter!
    private var mockPersonRepo: MockPersonRepository!
    private var mockGroupRepo: MockGroupRepository!
    private var mockSettingsRepo: MockSettingsRepository!
    private var sut: NotificationScheduler!

    private let groupId = UUID()

    override func setUp() {
        super.setUp()
        mockNotificationCenter = MockUserNotificationCenter()
        mockPersonRepo = MockPersonRepository()
        mockGroupRepo = MockGroupRepository()
        mockSettingsRepo = MockSettingsRepository()
        sut = NotificationScheduler(
            settingsRepository: mockSettingsRepo,
            personRepository: mockPersonRepo,
            groupRepository: mockGroupRepo,
            notificationCenter: mockNotificationCenter
        )
    }

    override func tearDown() {
        sut = nil
        mockNotificationCenter = nil
        mockPersonRepo = nil
        mockGroupRepo = nil
        mockSettingsRepo = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeSettingsWithNotifications(
        grouping: NotificationGrouping = .perType,
        badgeShowDueSoon: Bool = false,
        digestEnabled: Bool = false
    ) -> AppSettings {
        AppSettings(
            id: AppSettings.singletonId,
            theme: .system,
            notificationsEnabled: true,
            breachTimeOfDay: LocalTime(hour: 9, minute: 0),
            digestEnabled: digestEnabled,
            digestDay: .friday,
            digestTime: LocalTime(hour: 18, minute: 0),
            notificationGrouping: grouping,
            badgeCountShowDueSoon: badgeShowDueSoon,
            dueSoonWindowDays: 3,
            demoModeEnabled: false,
            analyticsEnabled: false,
            lastContactsSyncAt: nil,
            onboardingCompleted: true,
            appVersion: ""
        )
    }

    private func makeOverduePerson(name: String = "Alice", customBreachTime: LocalTime? = nil) -> Person {
        let lastTouch = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        var person = TestFactory.makePerson(
            name: name,
            groupId: groupId,
            lastTouchAt: lastTouch,
            lastTouchMethod: .call
        )
        person.customBreachTime = customBreachTime
        person.groupAddedAt = lastTouch
        return person
    }

    private func makeDueSoonPerson(name: String = "Bob") -> Person {
        let lastTouch = Calendar.current.date(byAdding: .day, value: -6, to: Date())!
        var person = TestFactory.makePerson(
            name: name,
            groupId: groupId,
            lastTouchAt: lastTouch,
            lastTouchMethod: .text
        )
        person.groupAddedAt = lastTouch
        return person
    }

    private func makeDueTodayPerson(name: String = "Carol") -> Person {
        let lastTouch = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        var person = TestFactory.makePerson(
            name: name,
            groupId: groupId,
            lastTouchAt: lastTouch,
            lastTouchMethod: .irl
        )
        person.groupAddedAt = lastTouch
        return person
    }

    private func seedWeeklyGroup() {
        mockGroupRepo.groups = [TestFactory.makeGroup(id: groupId, name: "Weekly", frequencyDays: 7)]
    }

    // MARK: - Notifications Disabled

    func testScheduleAll_notificationsDisabled_clearsAndSetsBadgeZero() async {
        mockSettingsRepo.settings = TestFactory.makeSettings()  // notificationsEnabled = false
        mockPersonRepo.people = [makeOverduePerson()]
        seedWeeklyGroup()

        await sut.scheduleAll()

        XCTAssertEqual(mockNotificationCenter.removeAllCallCount, 1, "Should clear existing notifications")
        XCTAssertEqual(mockNotificationCenter.badgeCounts, [0], "Should set badge to zero")
        XCTAssertTrue(mockNotificationCenter.addedRequests.isEmpty, "Should not schedule any notifications")
    }

    // MARK: - No Settings

    func testScheduleAll_noSettings_doesNothing() async {
        mockSettingsRepo.settings = nil

        await sut.scheduleAll()

        XCTAssertEqual(mockNotificationCenter.removeAllCallCount, 0)
        XCTAssertTrue(mockNotificationCenter.badgeCounts.isEmpty)
        XCTAssertTrue(mockNotificationCenter.addedRequests.isEmpty)
    }

    // MARK: - Clears Before Scheduling

    func testScheduleAll_clearsExistingRequestsFirst() async {
        mockSettingsRepo.settings = makeSettingsWithNotifications()
        seedWeeklyGroup()
        mockPersonRepo.people = [makeOverduePerson()]

        await sut.scheduleAll()

        XCTAssertGreaterThanOrEqual(mockNotificationCenter.removeAllCallCount, 1, "Should clear before scheduling")

        // Verify removeAll happens before any add
        if let removeIndex = mockNotificationCenter.operations.firstIndex(where: {
            if case .removeAll = $0 { return true }; return false
        }), let addIndex = mockNotificationCenter.operations.firstIndex(where: {
            if case .add = $0 { return true }; return false
        }) {
            XCTAssertLessThan(removeIndex, addIndex, "removeAll must happen before first add")
        }
    }

    // MARK: - Empty People

    func testScheduleAll_emptyPeople_schedulesNothing() async {
        mockSettingsRepo.settings = makeSettingsWithNotifications()
        seedWeeklyGroup()
        mockPersonRepo.people = []

        await sut.scheduleAll()

        XCTAssertTrue(mockNotificationCenter.addedRequests.isEmpty, "No people means no notifications")
        XCTAssertEqual(mockNotificationCenter.badgeCounts.last, 0, "Badge should be zero with no people")
    }

    // MARK: - Per-Type Grouping

    func testPerTypeGrouping_schedulesOneRequestPerType() async {
        mockSettingsRepo.settings = makeSettingsWithNotifications(grouping: .perType)
        seedWeeklyGroup()
        mockPersonRepo.people = [makeOverduePerson(), makeDueSoonPerson(), makeDueTodayPerson()]

        await sut.scheduleAll()

        let identifiers = mockNotificationCenter.addedRequests.map(\.identifier)
        XCTAssertTrue(identifiers.contains(NotificationIdentifier.dailyOverdue), "Should schedule overdue notification")
        XCTAssertTrue(identifiers.contains(NotificationIdentifier.dailyDueSoon), "Should schedule due-soon notification")
        XCTAssertTrue(identifiers.contains(NotificationIdentifier.dailyDueToday), "Should schedule due-today notification")
    }

    // MARK: - Per-Day Grouping

    func testPerDayGrouping_schedulesSingleCombinedRequest() async {
        mockSettingsRepo.settings = makeSettingsWithNotifications(grouping: .perDay)
        seedWeeklyGroup()
        mockPersonRepo.people = [makeOverduePerson(), makeDueSoonPerson()]

        await sut.scheduleAll()

        let identifiers = mockNotificationCenter.addedRequests.map(\.identifier)
        XCTAssertTrue(identifiers.contains(NotificationIdentifier.dailyCombined), "Should schedule combined daily notification")
        XCTAssertFalse(identifiers.contains(NotificationIdentifier.dailyOverdue), "Should not schedule per-type notifications")
    }

    // MARK: - Per-Person Grouping

    func testPerPersonGrouping_schedulesOneRequestPerPerson() async {
        mockSettingsRepo.settings = makeSettingsWithNotifications(grouping: .perPerson)
        seedWeeklyGroup()
        let alice = makeOverduePerson(name: "Alice")
        let bob = makeOverduePerson(name: "Bob")
        mockPersonRepo.people = [alice, bob]

        await sut.scheduleAll()

        let identifiers = mockNotificationCenter.addedRequests.map(\.identifier)
        XCTAssertTrue(identifiers.contains("\(NotificationIdentifier.dailyOverdue)_\(alice.id.uuidString)"))
        XCTAssertTrue(identifiers.contains("\(NotificationIdentifier.dailyOverdue)_\(bob.id.uuidString)"))
    }

    // MARK: - Badge Count

    func testBadgeCount_overdueOnly() async {
        mockSettingsRepo.settings = makeSettingsWithNotifications(badgeShowDueSoon: false)
        seedWeeklyGroup()
        mockPersonRepo.people = [makeOverduePerson(), makeDueSoonPerson()]

        await sut.scheduleAll()

        // Badge should only count overdue, not due-soon
        let finalBadge = mockNotificationCenter.badgeCounts.last
        XCTAssertNotNil(finalBadge)
        XCTAssertEqual(finalBadge, 1, "Badge should count only overdue person (1), not due-soon")
    }

    func testBadgeCount_includesDueSoon() async {
        mockSettingsRepo.settings = makeSettingsWithNotifications(badgeShowDueSoon: true)
        seedWeeklyGroup()
        mockPersonRepo.people = [makeOverduePerson(), makeDueSoonPerson()]

        await sut.scheduleAll()

        let finalBadge = mockNotificationCenter.badgeCounts.last
        XCTAssertNotNil(finalBadge)
        XCTAssertEqual(finalBadge, 2, "Badge should count overdue (1) + due-soon (1)")
    }

    // MARK: - Weekly Digest

    func testWeeklyDigest_scheduledWhenEnabled() async {
        mockSettingsRepo.settings = makeSettingsWithNotifications(digestEnabled: true)
        seedWeeklyGroup()
        mockPersonRepo.people = [makeOverduePerson()]

        await sut.scheduleAll()

        let identifiers = mockNotificationCenter.addedRequests.map(\.identifier)
        XCTAssertTrue(identifiers.contains(NotificationIdentifier.weeklyDigest), "Digest should be scheduled when enabled")
    }

    func testWeeklyDigest_notScheduledWhenDisabled() async {
        mockSettingsRepo.settings = makeSettingsWithNotifications(digestEnabled: false)
        seedWeeklyGroup()
        mockPersonRepo.people = [makeOverduePerson()]

        await sut.scheduleAll()

        let identifiers = mockNotificationCenter.addedRequests.map(\.identifier)
        XCTAssertFalse(identifiers.contains(NotificationIdentifier.weeklyDigest), "Digest should not be scheduled when disabled")
    }

    // MARK: - Custom Breach Time

    func testCustomOverrides_scheduledWithCustomIdentifier() async {
        mockSettingsRepo.settings = makeSettingsWithNotifications()
        seedWeeklyGroup()
        let customTime = LocalTime(hour: 8, minute: 30)
        let person = makeOverduePerson(name: "Custom", customBreachTime: customTime)
        mockPersonRepo.people = [person]

        await sut.scheduleAll()

        let identifiers = mockNotificationCenter.addedRequests.map(\.identifier)
        let expectedId = "\(NotificationIdentifier.dailyOverdue)_custom_\(person.id.uuidString)"
        XCTAssertTrue(identifiers.contains(expectedId), "Custom breach time should use custom identifier")
        // Should NOT appear in the standard overdue list
        XCTAssertFalse(identifiers.contains(NotificationIdentifier.dailyOverdue), "Custom person should not trigger standard overdue notification")
    }

    // MARK: - Register Categories

    func testRegisterCategories_setsPersonCategory() throws {
        sut.registerCategories()

        XCTAssertEqual(mockNotificationCenter.categoriesSet.count, 1)
        let category = try XCTUnwrap(mockNotificationCenter.categoriesSet.first)
        XCTAssertEqual(category.identifier, NotificationIdentifier.categoryPerson)
        XCTAssertEqual(category.actions.count, 1)
        let action = try XCTUnwrap(category.actions.first)
        XCTAssertEqual(action.identifier, NotificationIdentifier.actionLogConnection)
    }

    // MARK: - Notification Content

    func testSinglePersonNotification_containsPersonName() async throws {
        mockSettingsRepo.settings = makeSettingsWithNotifications(grouping: .perPerson)
        seedWeeklyGroup()
        let person = makeOverduePerson(name: "Sarah Chen")
        mockPersonRepo.people = [person]

        await sut.scheduleAll()

        let request = try XCTUnwrap(mockNotificationCenter.addedRequests.first)
        XCTAssertTrue(request.content.body.contains("Sarah"), "Notification body should contain person's name")
    }

    func testNotification_hasBadgeCount() async {
        mockSettingsRepo.settings = makeSettingsWithNotifications()
        seedWeeklyGroup()
        mockPersonRepo.people = [makeOverduePerson()]

        await sut.scheduleAll()

        let request = mockNotificationCenter.addedRequests.first
        XCTAssertNotNil(request?.content.badge, "Notification should include badge count")
    }

    func testNotification_usesRepeatingCalendarTrigger() async throws {
        mockSettingsRepo.settings = makeSettingsWithNotifications()
        seedWeeklyGroup()
        mockPersonRepo.people = [makeOverduePerson()]

        await sut.scheduleAll()

        let request = try XCTUnwrap(mockNotificationCenter.addedRequests.first)
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger, "Should use calendar trigger")
        XCTAssertTrue(trigger.repeats, "Trigger should repeat")
    }
}
