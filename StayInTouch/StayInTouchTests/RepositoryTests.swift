//
//  RepositoryTests.swift
//  KeepInTouchTests
//
//  Created by Codex on 2/2/26.
//

import CoreData
import XCTest
@testable import StayInTouch

final class RepositoryTests: XCTestCase {
    private var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        let testStack = CoreDataTestStack()
        context = testStack.container.viewContext
    }

    func testCadenceRepositoryCrud() throws {
        let repo = CoreDataCadenceRepository(context: context)
        let cadence = Cadence(
            id: UUID(),
            name: "Weekly",
            frequencyDays: 7,
            warningDays: 2,
            colorHex: nil,
            isDefault: true,
            sortOrder: 0,
            createdAt: Date(),
            modifiedAt: Date()
        )

        try repo.save(cadence)
        XCTAssertEqual(repo.fetchAll().count, 1)
        XCTAssertEqual(repo.fetch(id: cadence.id)?.name, "Weekly")

        try repo.delete(id: cadence.id)
        XCTAssertEqual(repo.fetchAll().count, 0)
    }

    func testGroupRepositoryCrud() throws {
        let repo = CoreDataGroupRepository(context: context)
        let group = Group(
            id: UUID(),
            name: "Work",
            colorHex: "#0A84FF",
            sortOrder: 0,
            createdAt: Date(),
            modifiedAt: Date()
        )

        try repo.save(group)
        XCTAssertEqual(repo.fetchAll().count, 1)
        XCTAssertEqual(repo.fetch(id: group.id)?.name, "Work")

        try repo.delete(id: group.id)
        XCTAssertEqual(repo.fetchAll().count, 0)
    }

    func testPersonRepositoryCrud() throws {
        let cadenceId = UUID()
        let repo = CoreDataPersonRepository(context: context)
        let person = Person(
            id: UUID(),
            cnIdentifier: nil,
            displayName: "Alex Doe",
            initials: "AD",
            avatarColor: "#FF6B6B",
            cadenceId: cadenceId,
            groupIds: [],
            lastTouchAt: nil,
            lastTouchMethod: nil,
            lastTouchNotes: nil,
            nextTouchNotes: nil,
            isPaused: false,
            isTracked: true,
            notificationsMuted: false,
            customBreachTime: nil,
            snoozedUntil: nil,
            customDueDate: nil,
            birthday: nil,
            birthdayNotificationsEnabled: true,
            contactUnavailable: false,
            isDemoData: false,
            cadenceAddedAt: nil,
            createdAt: Date(),
            modifiedAt: Date(),
            sortOrder: 0
        )

        try repo.save(person)
        XCTAssertEqual(repo.fetchAll().count, 1)
        XCTAssertEqual(repo.fetch(id: person.id)?.displayName, "Alex Doe")

        try repo.delete(id: person.id)
        XCTAssertEqual(repo.fetchAll().count, 0)
    }

    func testTouchEventRepositoryCrud() throws {
        let personId = UUID()
        let repo = CoreDataTouchEventRepository(context: context)
        let touch = TouchEvent(
            id: UUID(),
            personId: personId,
            at: Date(),
            method: .call,
            notes: "Test",
            timeOfDay: nil,
            createdAt: Date(),
            modifiedAt: Date()
        )

        try repo.save(touch)
        XCTAssertEqual(repo.fetchAll(for: personId).count, 1)
        XCTAssertEqual(repo.fetch(id: touch.id)?.method, .call)

        try repo.delete(id: touch.id)
        XCTAssertEqual(repo.fetchAll(for: personId).count, 0)
    }

    func testAppSettingsRepositoryCrud() throws {
        let repo = CoreDataAppSettingsRepository(context: context)
        let settings = AppSettings(
            id: AppSettings.singletonId,
            theme: .light,
            notificationsEnabled: false,
            breachTimeOfDay: LocalTime(hour: 18, minute: 0),
            digestEnabled: false,
            digestDay: .friday,
            digestTime: LocalTime(hour: 18, minute: 0),
            notificationGrouping: .perType,
            badgeCountShowDueSoon: false,
            dueSoonWindowDays: 3,
            demoModeEnabled: false,
            analyticsEnabled: true,
            hideContactNamesInNotifications: false,
            birthdayNotificationsEnabled: false,
            birthdayNotificationTime: LocalTime(hour: 9, minute: 0),
            birthdayIgnoreSnoozePause: true,
            lastContactsSyncAt: nil,
            onboardingCompleted: false,
            appVersion: "1.0"
        )

        try repo.save(settings)
        XCTAssertEqual(repo.fetch()?.id, AppSettings.singletonId)
    }
}
