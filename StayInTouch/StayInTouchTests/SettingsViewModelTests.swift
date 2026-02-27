//
//  SettingsViewModelTests.swift
//  StayInTouchTests
//
//  Created by Codex on 2/24/26.
//

import XCTest
@testable import StayInTouch

@MainActor
final class SettingsViewModelTests: XCTestCase {
    private var settingsRepo: MockSettingsRepository!
    private var groupRepo: MockGroupRepository!
    private var tagRepo: MockTagRepository!
    private var personRepo: MockPersonRepository!
    private var sut: SettingsViewModel!

    override func setUp() {
        super.setUp()
        settingsRepo = MockSettingsRepository()
        settingsRepo.settings = TestFactory.makeSettings()
        groupRepo = MockGroupRepository()
        tagRepo = MockTagRepository()
        personRepo = MockPersonRepository()

        sut = SettingsViewModel(
            settingsRepository: settingsRepo,
            groupRepository: groupRepo,
            tagRepository: tagRepo,
            personRepository: personRepo
        )
    }

    // MARK: - Export

    func testExportContactsReturnsFileWithValidJSON() throws {
        personRepo.people = [
            TestFactory.makePerson(name: "Alice"),
            TestFactory.makePerson(name: "Bob")
        ]
        // Reload to pick up the people
        sut = SettingsViewModel(
            settingsRepository: settingsRepo,
            groupRepository: groupRepo,
            tagRepository: tagRepo,
            personRepository: personRepo
        )

        let url = sut.exportContacts()

        XCTAssertNotNil(url)
        let data = try Data(contentsOf: url!)
        let decoded = try JSONDecoder().decode([ExportPerson].self, from: data)
        XCTAssertEqual(decoded.count, 2)

        // Clean up temp file
        try? FileManager.default.removeItem(at: url!)
    }

    func testExportEmptyContactsReturnsEmptyArray() throws {
        let url = sut.exportContacts()

        XCTAssertNotNil(url)
        let data = try Data(contentsOf: url!)
        let decoded = try JSONDecoder().decode([ExportPerson].self, from: data)
        XCTAssertTrue(decoded.isEmpty)

        try? FileManager.default.removeItem(at: url!)
    }

    // MARK: - Demo Mode

    func testSetDemoModeEnabledUpdatesSettings() {
        sut.setDemoModeEnabled(true)

        XCTAssertTrue(sut.settings.demoModeEnabled)
        XCTAssertTrue(settingsRepo.settings?.demoModeEnabled == true)
    }

    func testSetDemoModeDisabledUpdatesSettings() {
        sut.setDemoModeEnabled(true)
        sut.setDemoModeEnabled(false)

        XCTAssertFalse(sut.settings.demoModeEnabled)
        XCTAssertFalse(settingsRepo.settings?.demoModeEnabled == true)
    }

    // MARK: - Settings Persistence

    func testSetThemePersists() {
        sut.setTheme(.dark)

        XCTAssertEqual(sut.settings.theme, .dark)
        XCTAssertEqual(settingsRepo.settings?.theme, .dark)
    }

    func testSetBreachTimePersists() {
        let time = LocalTime(hour: 9, minute: 30)
        sut.setBreachTime(time)

        XCTAssertEqual(sut.settings.breachTimeOfDay, time)
        XCTAssertEqual(settingsRepo.settings?.breachTimeOfDay, time)
    }

    func testSetDigestEnabledPersists() {
        sut.setDigestEnabled(true)

        XCTAssertTrue(sut.settings.digestEnabled)
        XCTAssertTrue(settingsRepo.settings?.digestEnabled == true)
    }

    func testSetDigestDayPersists() {
        sut.setDigestDay(.monday)

        XCTAssertEqual(sut.settings.digestDay, .monday)
        XCTAssertEqual(settingsRepo.settings?.digestDay, .monday)
    }

    func testSetDigestTimePersists() {
        let time = LocalTime(hour: 10, minute: 0)
        sut.setDigestTime(time)

        XCTAssertEqual(sut.settings.digestTime, time)
        XCTAssertEqual(settingsRepo.settings?.digestTime, time)
    }

    func testSetNotificationGroupingPersists() {
        sut.setNotificationGrouping(.perPerson)

        XCTAssertEqual(sut.settings.notificationGrouping, .perPerson)
        XCTAssertEqual(settingsRepo.settings?.notificationGrouping, .perPerson)
    }

    // MARK: - Load Counts

    func testLoadRefreshesGroupTagPausedCounts() {
        groupRepo.groups = [
            TestFactory.makeGroup(name: "Weekly"),
            TestFactory.makeGroup(name: "Monthly"),
            TestFactory.makeGroup(name: "Quarterly")
        ]
        tagRepo.tags = [
            TestFactory.makeTag(name: "Work"),
            TestFactory.makeTag(name: "Family")
        ]
        personRepo.people = [
            TestFactory.makePerson(name: "Active"),
            TestFactory.makePerson(name: "Paused", isPaused: true)
        ]

        sut.load()

        XCTAssertEqual(sut.groupsCount, 3)
        XCTAssertEqual(sut.tagsCount, 2)
        XCTAssertEqual(sut.pausedCount, 1)
    }
}
