//
//  NotificationSchedulerTests.swift
//  KeepInTouchTests
//

import XCTest
@testable import StayInTouch

final class NotificationSchedulerTests: XCTestCase {

    private var mockNotificationCenter: MockUserNotificationCenter!
    private var mockPersonRepo: MockPersonRepository!
    private var mockCadenceRepo: MockCadenceRepository!
    private var mockSettingsRepo: MockSettingsRepository!
    private var sut: NotificationScheduler!

    private let cadenceId = UUID()

    override func setUp() {
        super.setUp()
        mockNotificationCenter = MockUserNotificationCenter()
        mockPersonRepo = MockPersonRepository()
        mockCadenceRepo = MockCadenceRepository()
        mockSettingsRepo = MockSettingsRepository()
        sut = NotificationScheduler(
            settingsRepository: mockSettingsRepo,
            personRepository: mockPersonRepo,
            cadenceRepository: mockCadenceRepo,
            notificationCenter: mockNotificationCenter
        )
    }

    override func tearDown() {
        sut = nil
        mockNotificationCenter = nil
        mockPersonRepo = nil
        mockCadenceRepo = nil
        mockSettingsRepo = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeSettingsWithNotifications(
        grouping: NotificationGrouping = .perType,
        notificationsEnabled: Bool = true,
        badgeShowDueSoon: Bool = false,
        digestEnabled: Bool = false,
        hideNames: Bool = false,
        birthdayNotificationsEnabled: Bool = false,
        birthdayIgnoreSnoozePause: Bool = true
    ) -> AppSettings {
        AppSettings(
            id: AppSettings.singletonId,
            theme: .system,
            notificationsEnabled: notificationsEnabled,
            breachTimeOfDay: LocalTime(hour: 9, minute: 0),
            digestEnabled: digestEnabled,
            digestDay: .friday,
            digestTime: LocalTime(hour: 18, minute: 0),
            notificationGrouping: grouping,
            badgeCountShowDueSoon: badgeShowDueSoon,
            dueSoonWindowDays: 3,
            demoModeEnabled: false,
            analyticsEnabled: false,
            hideContactNamesInNotifications: hideNames,
            birthdayNotificationsEnabled: birthdayNotificationsEnabled,
            birthdayNotificationTime: LocalTime(hour: 9, minute: 0),
            birthdayIgnoreSnoozePause: birthdayIgnoreSnoozePause,
            lastContactsSyncAt: nil,
            onboardingCompleted: true,
            appVersion: ""
        )
    }

    private func makeOverduePerson(name: String = "Alice", customBreachTime: LocalTime? = nil) -> Person {
        let lastTouch = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        var person = TestFactory.makePerson(
            name: name,
            cadenceId: cadenceId,
            lastTouchAt: lastTouch,
            lastTouchMethod: .call
        )
        person.customBreachTime = customBreachTime
        person.cadenceAddedAt = lastTouch
        return person
    }

    private func makeDueSoonPerson(name: String = "Bob") -> Person {
        let lastTouch = Calendar.current.date(byAdding: .day, value: -6, to: Date())!
        var person = TestFactory.makePerson(
            name: name,
            cadenceId: cadenceId,
            lastTouchAt: lastTouch,
            lastTouchMethod: .text
        )
        person.cadenceAddedAt = lastTouch
        return person
    }

    private func makeDueTodayPerson(name: String = "Carol") -> Person {
        let lastTouch = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        var person = TestFactory.makePerson(
            name: name,
            cadenceId: cadenceId,
            lastTouchAt: lastTouch,
            lastTouchMethod: .irl
        )
        person.cadenceAddedAt = lastTouch
        return person
    }

    private func seedWeeklyGroup() {
        mockCadenceRepo.cadences = [TestFactory.makeCadence(id: cadenceId, name: "Weekly", frequencyDays: 7)]
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
        // Two people: digest fires (dedup only suppresses single-person case)
        mockSettingsRepo.settings = makeSettingsWithNotifications(digestEnabled: true)
        seedWeeklyGroup()
        mockPersonRepo.people = [makeOverduePerson(name: "Alice"), makeOverduePerson(name: "Bob")]

        await sut.scheduleAll()

        let identifiers = mockNotificationCenter.addedRequests.map(\.identifier)
        XCTAssertTrue(identifiers.contains(NotificationIdentifier.weeklyDigest), "Digest should be scheduled when there are multiple people")
    }

    func testWeeklyDigest_notScheduledWhenDisabled() async {
        mockSettingsRepo.settings = makeSettingsWithNotifications(digestEnabled: false)
        seedWeeklyGroup()
        mockPersonRepo.people = [makeOverduePerson()]

        await sut.scheduleAll()

        let identifiers = mockNotificationCenter.addedRequests.map(\.identifier)
        XCTAssertFalse(identifiers.contains(NotificationIdentifier.weeklyDigest), "Digest should not be scheduled when disabled")
    }

    // MARK: - Digest Deduplication (#230)

    func testWeeklyDigest_suppressedForSinglePersonWhenDailyEnabled() async {
        // Single person + daily notifications enabled → digest is redundant, suppress it
        mockSettingsRepo.settings = makeSettingsWithNotifications(digestEnabled: true)
        seedWeeklyGroup()
        mockPersonRepo.people = [makeOverduePerson()]

        await sut.scheduleAll()

        let identifiers = mockNotificationCenter.addedRequests.map(\.identifier)
        XCTAssertFalse(identifiers.contains(NotificationIdentifier.weeklyDigest),
                       "Digest should be suppressed for a single person when daily breach notifications are also enabled")
    }

    func testWeeklyDigest_suppressedWhenEmpty() async {
        // No overdue people → digest is not scheduled regardless of settings
        mockSettingsRepo.settings = makeSettingsWithNotifications(digestEnabled: true)
        seedWeeklyGroup()
        mockPersonRepo.people = []

        await sut.scheduleAll()

        let identifiers = mockNotificationCenter.addedRequests.map(\.identifier)
        XCTAssertFalse(identifiers.contains(NotificationIdentifier.weeklyDigest),
                       "Digest should not be scheduled when there are no overdue people")
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

    func testRegisterCategories_setsPersonAndBirthdayCategories() throws {
        sut.registerCategories()

        XCTAssertEqual(mockNotificationCenter.categoriesSet.count, 2)
        let identifiers = Set(mockNotificationCenter.categoriesSet.map(\.identifier))
        XCTAssertTrue(identifiers.contains(NotificationIdentifier.categoryPerson))
        XCTAssertTrue(identifiers.contains(NotificationIdentifier.categoryBirthday))
        for category in mockNotificationCenter.categoriesSet {
            XCTAssertEqual(category.actions.count, 1)
            let action = try XCTUnwrap(category.actions.first)
            XCTAssertEqual(action.identifier, NotificationIdentifier.actionLogConnection)
        }
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

    // MARK: - Hide Names in Notifications

    func testHideNames_perTypeSinglePerson_omitsName() async {
        mockSettingsRepo.settings = makeSettingsWithNotifications(hideNames: true)
        seedWeeklyGroup()
        mockPersonRepo.people = [makeOverduePerson(name: "Alice")]

        await sut.scheduleAll()

        let bodies = mockNotificationCenter.addedRequests.map(\.content.body)
        for body in bodies {
            XCTAssertFalse(body.contains("Alice"), "Notification body should not contain name when hideNames is true, got: \(body)")
        }
    }

    func testHideNames_perPersonGrouping_omitsName() async {
        mockSettingsRepo.settings = makeSettingsWithNotifications(grouping: .perPerson, hideNames: true)
        seedWeeklyGroup()
        mockPersonRepo.people = [makeOverduePerson(name: "Bob")]

        await sut.scheduleAll()

        let bodies = mockNotificationCenter.addedRequests.map(\.content.body)
        for body in bodies {
            XCTAssertFalse(body.contains("Bob"), "Per-person notification should not contain name when hideNames is true, got: \(body)")
        }
    }

    func testHideNames_multipleOverdue_omitsNames() async {
        mockSettingsRepo.settings = makeSettingsWithNotifications(hideNames: true)
        seedWeeklyGroup()
        mockPersonRepo.people = [makeOverduePerson(name: "Carol"), makeOverduePerson(name: "Dave")]

        await sut.scheduleAll()

        let bodies = mockNotificationCenter.addedRequests.map(\.content.body)
        for body in bodies {
            XCTAssertFalse(body.contains("Carol"), "Should not contain Carol, got: \(body)")
            XCTAssertFalse(body.contains("Dave"), "Should not contain Dave, got: \(body)")
        }
    }

    func testHideNames_disabled_includesName() async {
        mockSettingsRepo.settings = makeSettingsWithNotifications(grouping: .perPerson, hideNames: false)
        seedWeeklyGroup()
        mockPersonRepo.people = [makeOverduePerson(name: "Eve")]

        await sut.scheduleAll()

        let bodies = mockNotificationCenter.addedRequests.map(\.content.body)
        let hasName = bodies.contains { $0.contains("Eve") }
        XCTAssertTrue(hasName, "Notification should contain name when hideNames is false")
    }

    // MARK: - Birthday Notifications

    private func makePersonWithBirthday(
        name: String = "Alice",
        birthday: Birthday = Birthday(month: 3, day: 15, year: nil),
        birthdayNotificationsEnabled: Bool = true,
        notificationsMuted: Bool = false,
        isPaused: Bool = false,
        snoozedUntil: Date? = nil
    ) -> Person {
        var person = TestFactory.makePerson(
            name: name,
            cadenceId: cadenceId,
            birthdayNotificationsEnabled: birthdayNotificationsEnabled
        )
        person.birthday = birthday
        person.notificationsMuted = notificationsMuted
        person.isPaused = isPaused
        person.snoozedUntil = snoozedUntil
        return person
    }

    func testBirthday_globalDisabled_schedulesNone() async {
        mockSettingsRepo.settings = makeSettingsWithNotifications(birthdayNotificationsEnabled: false)
        seedWeeklyGroup()
        mockPersonRepo.people = [makePersonWithBirthday()]

        await sut.scheduleAll()

        let birthdayRequests = mockNotificationCenter.addedRequests.filter {
            $0.identifier.hasPrefix(NotificationIdentifier.birthdayPrefix)
        }
        XCTAssertTrue(birthdayRequests.isEmpty, "No birthday notifications when global toggle is off")
    }

    func testBirthday_globalEnabled_schedulesNotification() async throws {
        mockSettingsRepo.settings = makeSettingsWithNotifications(birthdayNotificationsEnabled: true)
        seedWeeklyGroup()
        let person = makePersonWithBirthday(birthday: Birthday(month: 7, day: 4, year: nil))
        mockPersonRepo.people = [person]

        await sut.scheduleAll()

        let birthdayRequests = mockNotificationCenter.addedRequests.filter {
            $0.identifier.hasPrefix(NotificationIdentifier.birthdayPrefix)
        }
        XCTAssertEqual(birthdayRequests.count, 1)

        let request = try XCTUnwrap(birthdayRequests.first)
        XCTAssertEqual(request.identifier, "\(NotificationIdentifier.birthdayPrefix)\(person.id.uuidString)")

        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(trigger.dateComponents.month, 7)
        XCTAssertEqual(trigger.dateComponents.day, 4)
        XCTAssertEqual(trigger.dateComponents.hour, 9)
        XCTAssertEqual(trigger.dateComponents.minute, 0)
        XCTAssertTrue(trigger.repeats, "Birthday trigger should repeat yearly")
    }

    func testBirthday_perPersonDisabled_skips() async {
        mockSettingsRepo.settings = makeSettingsWithNotifications(birthdayNotificationsEnabled: true)
        seedWeeklyGroup()
        mockPersonRepo.people = [makePersonWithBirthday(birthdayNotificationsEnabled: false)]

        await sut.scheduleAll()

        let birthdayRequests = mockNotificationCenter.addedRequests.filter {
            $0.identifier.hasPrefix(NotificationIdentifier.birthdayPrefix)
        }
        XCTAssertTrue(birthdayRequests.isEmpty, "Should skip person with birthday notifications disabled")
    }

    func testBirthday_noBirthday_skips() async {
        mockSettingsRepo.settings = makeSettingsWithNotifications(birthdayNotificationsEnabled: true)
        seedWeeklyGroup()
        var person = TestFactory.makePerson(name: "NoBday", cadenceId: cadenceId)
        person.birthday = nil
        mockPersonRepo.people = [person]

        await sut.scheduleAll()

        let birthdayRequests = mockNotificationCenter.addedRequests.filter {
            $0.identifier.hasPrefix(NotificationIdentifier.birthdayPrefix)
        }
        XCTAssertTrue(birthdayRequests.isEmpty, "Should skip person with no birthday")
    }

    func testBirthday_mutedNotifications_skips() async {
        mockSettingsRepo.settings = makeSettingsWithNotifications(birthdayNotificationsEnabled: true)
        seedWeeklyGroup()
        mockPersonRepo.people = [makePersonWithBirthday(notificationsMuted: true)]

        await sut.scheduleAll()

        let birthdayRequests = mockNotificationCenter.addedRequests.filter {
            $0.identifier.hasPrefix(NotificationIdentifier.birthdayPrefix)
        }
        XCTAssertTrue(birthdayRequests.isEmpty, "Should skip person with muted notifications")
    }

    func testBirthday_snoozed_skipsWhenOverrideOff() async {
        mockSettingsRepo.settings = makeSettingsWithNotifications(
            birthdayNotificationsEnabled: true,
            birthdayIgnoreSnoozePause: false
        )
        seedWeeklyGroup()
        let future = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        mockPersonRepo.people = [makePersonWithBirthday(snoozedUntil: future)]

        await sut.scheduleAll()

        let birthdayRequests = mockNotificationCenter.addedRequests.filter {
            $0.identifier.hasPrefix(NotificationIdentifier.birthdayPrefix)
        }
        XCTAssertTrue(birthdayRequests.isEmpty, "Should skip snoozed person when override is off")
    }

    func testBirthday_snoozed_firesWhenOverrideOn() async {
        mockSettingsRepo.settings = makeSettingsWithNotifications(
            birthdayNotificationsEnabled: true,
            birthdayIgnoreSnoozePause: true
        )
        seedWeeklyGroup()
        let future = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        mockPersonRepo.people = [makePersonWithBirthday(snoozedUntil: future)]

        await sut.scheduleAll()

        let birthdayRequests = mockNotificationCenter.addedRequests.filter {
            $0.identifier.hasPrefix(NotificationIdentifier.birthdayPrefix)
        }
        XCTAssertEqual(birthdayRequests.count, 1, "Should schedule birthday for snoozed person when override is on")
    }

    func testBirthday_paused_firesWhenOverrideOn() async {
        mockSettingsRepo.settings = makeSettingsWithNotifications(
            birthdayNotificationsEnabled: true,
            birthdayIgnoreSnoozePause: true
        )
        seedWeeklyGroup()
        mockPersonRepo.people = [makePersonWithBirthday(isPaused: true)]

        await sut.scheduleAll()

        let birthdayRequests = mockNotificationCenter.addedRequests.filter {
            $0.identifier.hasPrefix(NotificationIdentifier.birthdayPrefix)
        }
        XCTAssertEqual(birthdayRequests.count, 1, "Should schedule birthday for paused person when override is on")
    }

    func testBirthday_hideNames_omitsPersonName() async throws {
        mockSettingsRepo.settings = makeSettingsWithNotifications(hideNames: true, birthdayNotificationsEnabled: true)
        seedWeeklyGroup()
        mockPersonRepo.people = [makePersonWithBirthday(name: "SecretPerson")]

        await sut.scheduleAll()

        let birthdayRequests = mockNotificationCenter.addedRequests.filter {
            $0.identifier.hasPrefix(NotificationIdentifier.birthdayPrefix)
        }
        let request = try XCTUnwrap(birthdayRequests.first)
        XCTAssertFalse(request.content.body.contains("SecretPerson"), "Birthday notification should not contain name when hideNames is true")
    }

    func testBirthday_firesIndependentlyOfDailyReminders() async {
        // Daily reminders OFF but birthday notifications ON
        var settings = makeSettingsWithNotifications(birthdayNotificationsEnabled: true)
        settings.notificationsEnabled = false
        mockSettingsRepo.settings = settings
        seedWeeklyGroup()
        mockPersonRepo.people = [makePersonWithBirthday()]

        await sut.scheduleAll()

        let birthdayRequests = mockNotificationCenter.addedRequests.filter {
            $0.identifier.hasPrefix(NotificationIdentifier.birthdayPrefix)
        }
        XCTAssertEqual(birthdayRequests.count, 1, "Birthday notifications should fire even when daily reminders are off")

        // No daily reminders should be scheduled
        let dailyRequests = mockNotificationCenter.addedRequests.filter {
            $0.identifier.hasPrefix("daily_")
        }
        XCTAssertTrue(dailyRequests.isEmpty, "Daily reminders should not fire when disabled")
    }

    func testBirthday_correctThreadAndCategory() async throws {
        mockSettingsRepo.settings = makeSettingsWithNotifications(birthdayNotificationsEnabled: true)
        seedWeeklyGroup()
        mockPersonRepo.people = [makePersonWithBirthday()]

        await sut.scheduleAll()

        let birthdayRequests = mockNotificationCenter.addedRequests.filter {
            $0.identifier.hasPrefix(NotificationIdentifier.birthdayPrefix)
        }
        let request = try XCTUnwrap(birthdayRequests.first)
        XCTAssertEqual(request.content.threadIdentifier, "birthday")
        XCTAssertEqual(request.content.categoryIdentifier, NotificationIdentifier.categoryBirthday)
    }

    func testBirthday_includesPersonId_inUserInfo() async throws {
        mockSettingsRepo.settings = makeSettingsWithNotifications(birthdayNotificationsEnabled: true)
        seedWeeklyGroup()
        let person = makePersonWithBirthday()
        mockPersonRepo.people = [person]

        await sut.scheduleAll()

        let birthdayRequests = mockNotificationCenter.addedRequests.filter {
            $0.identifier.hasPrefix(NotificationIdentifier.birthdayPrefix)
        }
        let request = try XCTUnwrap(birthdayRequests.first)
        XCTAssertEqual(request.content.userInfo["personId"] as? String, person.id.uuidString)
        XCTAssertEqual(request.content.userInfo["type"] as? String, "person")
        XCTAssertEqual(request.content.userInfo["category"] as? String, "birthday")
    }

    // MARK: - Birthday Grouping

    func testBirthday_twoPeopleSameBirthday_schedulesSingleGroupedNotification() async {
        mockSettingsRepo.settings = makeSettingsWithNotifications(birthdayNotificationsEnabled: true)
        seedWeeklyGroup()
        let alice = makePersonWithBirthday(name: "Alice", birthday: Birthday(month: 6, day: 10, year: nil))
        let bob = makePersonWithBirthday(name: "Bob", birthday: Birthday(month: 6, day: 10, year: nil))
        mockPersonRepo.people = [alice, bob]

        await sut.scheduleAll()

        let birthdayRequests = mockNotificationCenter.addedRequests.filter {
            $0.identifier.hasPrefix(NotificationIdentifier.birthdayPrefix)
        }
        XCTAssertEqual(birthdayRequests.count, 1, "Two people sharing a birthday should produce one grouped notification")
        XCTAssertTrue(birthdayRequests[0].identifier.hasPrefix(NotificationIdentifier.birthdayGroupedPrefix),
                      "Grouped notification should use grouped prefix")
    }

    func testBirthday_twoPeopleSameBirthday_bodyContainsBothNames() async throws {
        mockSettingsRepo.settings = makeSettingsWithNotifications(birthdayNotificationsEnabled: true)
        seedWeeklyGroup()
        let alice = makePersonWithBirthday(name: "Alice", birthday: Birthday(month: 6, day: 10, year: nil))
        let bob = makePersonWithBirthday(name: "Bob", birthday: Birthday(month: 6, day: 10, year: nil))
        mockPersonRepo.people = [alice, bob]

        await sut.scheduleAll()

        let request = try XCTUnwrap(mockNotificationCenter.addedRequests.first {
            $0.identifier.hasPrefix(NotificationIdentifier.birthdayGroupedPrefix)
        })
        XCTAssertTrue(request.content.body.contains("Alice"), "Combined body should contain Alice")
        XCTAssertTrue(request.content.body.contains("Bob"), "Combined body should contain Bob")
    }

    func testBirthday_threePlusPeopleSameBirthday_schedulesSingleGroupedNotification() async {
        mockSettingsRepo.settings = makeSettingsWithNotifications(birthdayNotificationsEnabled: true)
        seedWeeklyGroup()
        let people = ["Alice", "Bob", "Carol"].map {
            makePersonWithBirthday(name: $0, birthday: Birthday(month: 4, day: 1, year: nil))
        }
        mockPersonRepo.people = people

        await sut.scheduleAll()

        let birthdayRequests = mockNotificationCenter.addedRequests.filter {
            $0.identifier.hasPrefix(NotificationIdentifier.birthdayPrefix)
        }
        XCTAssertEqual(birthdayRequests.count, 1, "Three people sharing a birthday should produce one grouped notification")
    }

    func testBirthday_threePlusPeopleSameBirthday_bodyShowsOthersCount() async throws {
        mockSettingsRepo.settings = makeSettingsWithNotifications(birthdayNotificationsEnabled: true)
        seedWeeklyGroup()
        let people = ["Alice", "Bob", "Carol", "Dave"].map {
            makePersonWithBirthday(name: $0, birthday: Birthday(month: 4, day: 1, year: nil))
        }
        mockPersonRepo.people = people

        await sut.scheduleAll()

        let request = try XCTUnwrap(mockNotificationCenter.addedRequests.first {
            $0.identifier.hasPrefix(NotificationIdentifier.birthdayGroupedPrefix)
        })
        // Should mention 2 others (Alice + Bob shown, Carol + Dave = 2 others)
        XCTAssertTrue(request.content.body.contains("2 others"), "Body should mention 2 others for 4-person group")
    }

    func testBirthday_differentBirthdays_schedulesPerPersonNotifications() async {
        mockSettingsRepo.settings = makeSettingsWithNotifications(birthdayNotificationsEnabled: true)
        seedWeeklyGroup()
        let alice = makePersonWithBirthday(name: "Alice", birthday: Birthday(month: 3, day: 10, year: nil))
        let bob = makePersonWithBirthday(name: "Bob", birthday: Birthday(month: 5, day: 20, year: nil))
        mockPersonRepo.people = [alice, bob]

        await sut.scheduleAll()

        let birthdayRequests = mockNotificationCenter.addedRequests.filter {
            $0.identifier.hasPrefix(NotificationIdentifier.birthdayPrefix)
        }
        XCTAssertEqual(birthdayRequests.count, 2, "Different birthdays should each get individual notifications")
        // Neither should be grouped
        let groupedRequests = birthdayRequests.filter {
            $0.identifier.hasPrefix(NotificationIdentifier.birthdayGroupedPrefix)
        }
        XCTAssertTrue(groupedRequests.isEmpty, "No grouped notification when birthdays are on different days")
    }

    func testBirthday_grouped_hideNames_omitsAllNames() async throws {
        mockSettingsRepo.settings = makeSettingsWithNotifications(hideNames: true, birthdayNotificationsEnabled: true)
        seedWeeklyGroup()
        let alice = makePersonWithBirthday(name: "Alice", birthday: Birthday(month: 6, day: 10, year: nil))
        let bob = makePersonWithBirthday(name: "Bob", birthday: Birthday(month: 6, day: 10, year: nil))
        mockPersonRepo.people = [alice, bob]

        await sut.scheduleAll()

        let request = try XCTUnwrap(mockNotificationCenter.addedRequests.first {
            $0.identifier.hasPrefix(NotificationIdentifier.birthdayGroupedPrefix)
        })
        XCTAssertFalse(request.content.body.contains("Alice"), "Hidden-names grouped notification must not contain Alice")
        XCTAssertFalse(request.content.body.contains("Bob"), "Hidden-names grouped notification must not contain Bob")
        XCTAssertTrue(request.content.body.lowercased().contains("birthday") || request.content.body.lowercased().contains("contact"),
                      "Hidden-names body should reference birthdays or contacts generically")
    }

    func testBirthday_grouped_correctTriggerDate() async throws {
        mockSettingsRepo.settings = makeSettingsWithNotifications(birthdayNotificationsEnabled: true)
        seedWeeklyGroup()
        let alice = makePersonWithBirthday(name: "Alice", birthday: Birthday(month: 8, day: 25, year: nil))
        let bob = makePersonWithBirthday(name: "Bob", birthday: Birthday(month: 8, day: 25, year: nil))
        mockPersonRepo.people = [alice, bob]

        await sut.scheduleAll()

        let request = try XCTUnwrap(mockNotificationCenter.addedRequests.first {
            $0.identifier.hasPrefix(NotificationIdentifier.birthdayGroupedPrefix)
        })
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(trigger.dateComponents.month, 8)
        XCTAssertEqual(trigger.dateComponents.day, 25)
        XCTAssertEqual(trigger.dateComponents.hour, 9)
        XCTAssertEqual(trigger.dateComponents.minute, 0)
        XCTAssertTrue(trigger.repeats)
    }

    func testBirthday_grouped_userInfoIsHome() async throws {
        mockSettingsRepo.settings = makeSettingsWithNotifications(birthdayNotificationsEnabled: true)
        seedWeeklyGroup()
        let alice = makePersonWithBirthday(name: "Alice", birthday: Birthday(month: 6, day: 10, year: nil))
        let bob = makePersonWithBirthday(name: "Bob", birthday: Birthday(month: 6, day: 10, year: nil))
        mockPersonRepo.people = [alice, bob]

        await sut.scheduleAll()

        let request = try XCTUnwrap(mockNotificationCenter.addedRequests.first {
            $0.identifier.hasPrefix(NotificationIdentifier.birthdayGroupedPrefix)
        })
        XCTAssertEqual(request.content.userInfo["type"] as? String, "home")
        XCTAssertEqual(request.content.userInfo["category"] as? String, "birthday")
    }

    func testBirthday_mixedSameDayAndDifferentDay_schedulesCorrectly() async {
        mockSettingsRepo.settings = makeSettingsWithNotifications(birthdayNotificationsEnabled: true)
        seedWeeklyGroup()
        // Alice + Bob share a birthday → grouped
        let alice = makePersonWithBirthday(name: "Alice", birthday: Birthday(month: 6, day: 10, year: nil))
        let bob = makePersonWithBirthday(name: "Bob", birthday: Birthday(month: 6, day: 10, year: nil))
        // Carol has a different birthday → individual
        let carol = makePersonWithBirthday(name: "Carol", birthday: Birthday(month: 9, day: 5, year: nil))
        mockPersonRepo.people = [alice, bob, carol]

        await sut.scheduleAll()

        let birthdayRequests = mockNotificationCenter.addedRequests.filter {
            $0.identifier.hasPrefix(NotificationIdentifier.birthdayPrefix)
        }
        XCTAssertEqual(birthdayRequests.count, 2, "Should have 1 grouped + 1 individual = 2 total birthday notifications")

        let grouped = birthdayRequests.filter { $0.identifier.hasPrefix(NotificationIdentifier.birthdayGroupedPrefix) }
        let individual = birthdayRequests.filter { !$0.identifier.hasPrefix(NotificationIdentifier.birthdayGroupedPrefix) }
        XCTAssertEqual(grouped.count, 1, "One grouped notification for Alice+Bob")
        XCTAssertEqual(individual.count, 1, "One individual notification for Carol")
    }

    func testBirthday_grouped_hasNoCategoryIdentifier() async throws {
        // Grouped birthday notifications must not have a categoryIdentifier, because
        // the BIRTHDAY_REMINDER category includes a "Log Connection" action that
        // requires a personId — which grouped notifications don't have.
        mockSettingsRepo.settings = makeSettingsWithNotifications(birthdayNotificationsEnabled: true)
        seedWeeklyGroup()
        let alice = makePersonWithBirthday(name: "Alice", birthday: Birthday(month: 6, day: 10, year: nil))
        let bob = makePersonWithBirthday(name: "Bob", birthday: Birthday(month: 6, day: 10, year: nil))
        mockPersonRepo.people = [alice, bob]

        await sut.scheduleAll()

        let request = try XCTUnwrap(mockNotificationCenter.addedRequests.first {
            $0.identifier.hasPrefix(NotificationIdentifier.birthdayGroupedPrefix)
        })
        XCTAssertTrue(request.content.categoryIdentifier.isEmpty,
                      "Grouped birthday notification must not have a categoryIdentifier (no personId to log against)")
    }

    func testBirthday_single_hasCategoryIdentifier() async throws {
        // Single-person birthday notifications retain the category (Log Connection is meaningful)
        mockSettingsRepo.settings = makeSettingsWithNotifications(birthdayNotificationsEnabled: true)
        seedWeeklyGroup()
        mockPersonRepo.people = [makePersonWithBirthday(name: "Alice")]

        await sut.scheduleAll()

        let request = try XCTUnwrap(mockNotificationCenter.addedRequests.first {
            $0.identifier.hasPrefix(NotificationIdentifier.birthdayPrefix) &&
            !$0.identifier.hasPrefix(NotificationIdentifier.birthdayGroupedPrefix)
        })
        XCTAssertEqual(request.content.categoryIdentifier, NotificationIdentifier.categoryBirthday,
                       "Single-person birthday notification should retain categoryIdentifier for Log Connection action")
    }
}
