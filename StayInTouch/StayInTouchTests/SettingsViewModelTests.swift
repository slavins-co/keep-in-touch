//
//  SettingsViewModelTests.swift
//  KeepInTouchTests
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
    private var touchEventRepo: MockTouchEventRepository!
    private var sut: SettingsViewModel!

    override func setUp() {
        super.setUp()
        settingsRepo = MockSettingsRepository()
        settingsRepo.settings = TestFactory.makeSettings()
        groupRepo = MockGroupRepository()
        tagRepo = MockTagRepository()
        personRepo = MockPersonRepository()
        touchEventRepo = MockTouchEventRepository()

        sut = SettingsViewModel(
            settingsRepository: settingsRepo,
            groupRepository: groupRepo,
            tagRepository: tagRepo,
            personRepository: personRepo,
            touchEventRepository: touchEventRepo
        )
    }

    // MARK: - Export

    func testExportContactsReturnsFileWithValidJSON() throws {
        personRepo.people = [
            TestFactory.makePerson(name: "Alice"),
            TestFactory.makePerson(name: "Bob")
        ]
        sut = SettingsViewModel(
            settingsRepository: settingsRepo,
            groupRepository: groupRepo,
            tagRepository: tagRepo,
            personRepository: personRepo,
            touchEventRepository: touchEventRepo
        )

        let url = sut.exportContacts()

        XCTAssertNotNil(url)
        let data = try Data(contentsOf: url!)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExportData.self, from: data)
        XCTAssertEqual(decoded.version, 2)
        XCTAssertEqual(decoded.people.count, 2)

        try? FileManager.default.removeItem(at: url!)
    }

    func testExportEmptyContactsReturnsEmptyArray() throws {
        let url = sut.exportContacts()

        XCTAssertNotNil(url)
        let data = try Data(contentsOf: url!)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExportData.self, from: data)
        XCTAssertTrue(decoded.people.isEmpty)
        XCTAssertEqual(decoded.version, 2)

        try? FileManager.default.removeItem(at: url!)
    }

    func testExportIncludesGroupsAndTags() throws {
        let groupId = UUID()
        let tagId = UUID()
        groupRepo.groups = [TestFactory.makeGroup(id: groupId, name: "Weekly")]
        tagRepo.tags = [TestFactory.makeTag(id: tagId, name: "Work")]
        personRepo.people = [TestFactory.makePerson(name: "Alice", groupId: groupId, tagIds: [tagId])]
        sut = SettingsViewModel(
            settingsRepository: settingsRepo,
            groupRepository: groupRepo,
            tagRepository: tagRepo,
            personRepository: personRepo,
            touchEventRepository: touchEventRepo
        )

        let url = sut.exportContacts()!
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExportData.self, from: data)

        XCTAssertEqual(decoded.groups.count, 1)
        XCTAssertEqual(decoded.groups.first?.name, "Weekly")
        XCTAssertEqual(decoded.groups.first?.frequencyDays, 7)
        XCTAssertEqual(decoded.tags.count, 1)
        XCTAssertEqual(decoded.tags.first?.name, "Work")
        XCTAssertEqual(decoded.people.count, 1)

        try? FileManager.default.removeItem(at: url)
    }

    func testExportDoesNotIncludeCnIdentifier() throws {
        personRepo.people = [TestFactory.makePerson(name: "Alice", cnIdentifier: "some-cn-id")]
        sut = SettingsViewModel(
            settingsRepository: settingsRepo,
            groupRepository: groupRepo,
            tagRepository: tagRepo,
            personRepository: personRepo,
            touchEventRepository: touchEventRepo
        )

        let url = sut.exportContacts()!
        let data = try Data(contentsOf: url)
        let jsonString = String(data: data, encoding: .utf8)!

        XCTAssertFalse(jsonString.contains("cnIdentifier"))
        XCTAssertFalse(jsonString.contains("some-cn-id"))

        try? FileManager.default.removeItem(at: url)
    }

    func testParseImportFileLegacyFormat() throws {
        // Create a legacy-format JSON ([ExportPerson] array)
        let legacyPeople = [
            ExportPerson(
                id: UUID(),
                displayName: "Alice",
                groupId: nil,
                groupName: nil,
                tagIds: [],
                tagNames: [],
                lastTouchAt: nil,
                isPaused: false,
                createdAt: Date(),
                modifiedAt: Date(),
                touchEvents: nil,
                birthday: nil
            )
        ]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(legacyPeople)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("legacy-test.json")
        try data.write(to: url, options: .atomic)

        let preview = sut.parseImportFile(url: url)

        XCTAssertNotNil(preview)
        XCTAssertEqual(preview?.newPeople.count, 1)
        XCTAssertTrue(preview?.newGroups.isEmpty ?? false)
        XCTAssertTrue(preview?.newTags.isEmpty ?? false)

        try? FileManager.default.removeItem(at: url)
    }

    func testParseImportFileNewFormatWithGroups() throws {
        let groupId = UUID()
        let tagId = UUID()
        let exportData = ExportData(
            version: 2,
            exportedAt: Date(),
            groups: [ExportGroup(id: groupId, name: "Custom Frequency", frequencyDays: 21, warningDays: 3, colorHex: nil, sortOrder: 0, isDefault: false)],
            tags: [ExportTag(id: tagId, name: "Custom Group", colorHex: "#FF0000", sortOrder: 0)],
            people: [ExportPerson(
                id: UUID(),
                displayName: "Bob",
                groupId: groupId,
                groupName: "Custom Frequency",
                tagIds: [tagId],
                tagNames: ["Custom Group"],
                lastTouchAt: nil,
                isPaused: false,
                createdAt: Date(),
                modifiedAt: Date(),
                touchEvents: nil,
                birthday: nil
            )]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(exportData)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("new-format-test.json")
        try data.write(to: url, options: .atomic)

        let preview = sut.parseImportFile(url: url)

        XCTAssertNotNil(preview)
        XCTAssertEqual(preview?.newPeople.count, 1)
        XCTAssertEqual(preview?.newGroups.count, 1)
        XCTAssertEqual(preview?.newGroups.first?.name, "Custom Frequency")
        XCTAssertEqual(preview?.newTags.count, 1)
        XCTAssertEqual(preview?.newTags.first?.name, "Custom Group")

        try? FileManager.default.removeItem(at: url)
    }

    func testImportMergesGroupsByName() throws {
        // Set up existing group "Weekly"
        let existingGroupId = UUID()
        groupRepo.groups = [TestFactory.makeGroup(id: existingGroupId, name: "Weekly")]
        sut = SettingsViewModel(
            settingsRepository: settingsRepo,
            groupRepository: groupRepo,
            tagRepository: tagRepo,
            personRepository: personRepo,
            touchEventRepository: touchEventRepo
        )

        let importedGroupId = UUID()
        let exportData = ExportData(
            version: 2,
            exportedAt: Date(),
            groups: [ExportGroup(id: importedGroupId, name: "weekly", frequencyDays: 7, warningDays: 2, colorHex: nil, sortOrder: 0, isDefault: true)],
            tags: [],
            people: [ExportPerson(
                id: UUID(),
                displayName: "Charlie",
                groupId: importedGroupId,
                groupName: "weekly",
                tagIds: [],
                tagNames: [],
                lastTouchAt: nil,
                isPaused: false,
                createdAt: Date(),
                modifiedAt: Date(),
                touchEvents: nil,
                birthday: nil
            )]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(exportData)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("merge-test.json")
        try data.write(to: url, options: .atomic)

        let preview = sut.parseImportFile(url: url)

        XCTAssertNotNil(preview)
        // "weekly" matches existing "Weekly" — no new group created
        XCTAssertTrue(preview?.newGroups.isEmpty ?? false)
        // The imported group ID should map to existing group
        XCTAssertEqual(preview?.groupIdMap[importedGroupId], existingGroupId)

        try? FileManager.default.removeItem(at: url)
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
