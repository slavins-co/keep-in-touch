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
    private var cadenceRepo: MockCadenceRepository!
    private var groupRepo: MockGroupRepository!
    private var personRepo: MockPersonRepository!
    private var touchEventRepo: MockTouchEventRepository!
    private var sut: SettingsViewModel!

    override func setUp() {
        super.setUp()
        settingsRepo = MockSettingsRepository()
        settingsRepo.settings = TestFactory.makeSettings()
        cadenceRepo = MockCadenceRepository()
        groupRepo = MockGroupRepository()
        personRepo = MockPersonRepository()
        touchEventRepo = MockTouchEventRepository()

        sut = SettingsViewModel(
            settingsRepository: settingsRepo,
            cadenceRepository: cadenceRepo,
            groupRepository: groupRepo,
            personRepository: personRepo,
            touchEventRepository: touchEventRepo
        )
    }

    // MARK: - Export

    private func cleanupURLs(_ urls: [URL]) {
        for url in urls { try? FileManager.default.removeItem(at: url) }
    }

    func testExportContactsReturnsFileWithValidJSON() throws {
        personRepo.people = [
            TestFactory.makePerson(name: "Alice"),
            TestFactory.makePerson(name: "Bob")
        ]
        sut = SettingsViewModel(
            settingsRepository: settingsRepo,
            cadenceRepository: cadenceRepo,
            groupRepository: groupRepo,
            personRepository: personRepo,
            touchEventRepository: touchEventRepo
        )

        let urls = sut.exportContacts()
        XCTAssertEqual(urls.count, 1)
        let data = try Data(contentsOf: urls[0])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExportData.self, from: data)
        XCTAssertEqual(decoded.version, 3)
        XCTAssertEqual(decoded.people.count, 2)

        cleanupURLs(urls)
    }

    func testExportEmptyContactsReturnsEmptyArray() throws {
        let urls = sut.exportContacts()
        XCTAssertEqual(urls.count, 1)
        let data = try Data(contentsOf: urls[0])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExportData.self, from: data)
        XCTAssertTrue(decoded.people.isEmpty)
        XCTAssertEqual(decoded.version, 3)

        cleanupURLs(urls)
    }

    func testExportIncludesGroupsAndTags() throws {
        let cadenceId = UUID()
        let tagId = UUID()
        cadenceRepo.cadences = [TestFactory.makeCadence(id: cadenceId, name: "Weekly")]
        groupRepo.groups = [TestFactory.makeGroup(id: tagId, name: "Work")]
        personRepo.people = [TestFactory.makePerson(name: "Alice", cadenceId: cadenceId, groupIds: [tagId])]
        sut = SettingsViewModel(
            settingsRepository: settingsRepo,
            cadenceRepository: cadenceRepo,
            groupRepository: groupRepo,
            personRepository: personRepo,
            touchEventRepository: touchEventRepo
        )

        let urls = sut.exportContacts()
        let data = try Data(contentsOf: urls[0])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExportData.self, from: data)

        XCTAssertEqual(decoded.cadences.count, 1)
        XCTAssertEqual(decoded.cadences.first?.name, "Weekly")
        XCTAssertEqual(decoded.cadences.first?.frequencyDays, 7)
        XCTAssertEqual(decoded.groups.count, 1)
        XCTAssertEqual(decoded.groups.first?.name, "Work")
        XCTAssertEqual(decoded.people.count, 1)

        cleanupURLs(urls)
    }

    func testExportDoesNotIncludeCnIdentifier() throws {
        personRepo.people = [TestFactory.makePerson(name: "Alice", cnIdentifier: "some-cn-id")]
        sut = SettingsViewModel(
            settingsRepository: settingsRepo,
            cadenceRepository: cadenceRepo,
            groupRepository: groupRepo,
            personRepository: personRepo,
            touchEventRepository: touchEventRepo
        )

        let urls = sut.exportContacts()
        let data = try Data(contentsOf: urls[0])
        let jsonString = String(data: data, encoding: .utf8)!

        XCTAssertFalse(jsonString.contains("cnIdentifier"))
        XCTAssertFalse(jsonString.contains("some-cn-id"))

        cleanupURLs(urls)
    }

    // MARK: - CSV Export

    func testExportCSVReturnsTwoFilesWithHeaderAndRows() throws {
        let cadenceId = UUID()
        cadenceRepo.cadences = [TestFactory.makeCadence(id: cadenceId, name: "Weekly")]
        personRepo.people = [
            TestFactory.makePerson(name: "Alice", cadenceId: cadenceId),
            TestFactory.makePerson(name: "Bob", cadenceId: cadenceId)
        ]
        sut = SettingsViewModel(
            settingsRepository: settingsRepo,
            cadenceRepository: cadenceRepo,
            groupRepository: groupRepo,
            personRepository: personRepo,
            touchEventRepository: touchEventRepo
        )

        let urls = sut.exportContacts(format: .csv)
        XCTAssertEqual(urls.count, 2, "Should return contacts CSV + history CSV")

        let contactsCSV = try String(contentsOf: urls[0], encoding: .utf8)
        let lines = contactsCSV.components(separatedBy: "\r\n")
        XCTAssertEqual(lines.first, "Name,Cadence,Groups,Status,Birthday,Last Touched,Last Touch Method,Paused,Notes,Touch Count")
        XCTAssertEqual(lines.count, 3) // header + 2 rows
        XCTAssertTrue(lines[1].contains("Alice"))
        XCTAssertTrue(lines[2].contains("Bob"))

        cleanupURLs(urls)
    }

    func testExportCSVEscapesCommasAndQuotes() throws {
        personRepo.people = [TestFactory.makePerson(name: "Smith, John")]
        sut = SettingsViewModel(
            settingsRepository: settingsRepo,
            cadenceRepository: cadenceRepo,
            groupRepository: groupRepo,
            personRepository: personRepo,
            touchEventRepository: touchEventRepo
        )

        let urls = sut.exportContacts(format: .csv)
        let contactsCSV = try String(contentsOf: urls[0], encoding: .utf8)
        XCTAssertTrue(contactsCSV.contains("\"Smith, John\""))

        cleanupURLs(urls)
    }

    func testExportCSVEmptyContactsReturnsHeaderOnly() throws {
        let urls = sut.exportContacts(format: .csv)
        XCTAssertEqual(urls.count, 2)

        let contactsCSV = try String(contentsOf: urls[0], encoding: .utf8)
        let contactLines = contactsCSV.components(separatedBy: "\r\n")
        XCTAssertEqual(contactLines.count, 1) // header only

        let historyCSV = try String(contentsOf: urls[1], encoding: .utf8)
        let historyLines = historyCSV.components(separatedBy: "\r\n")
        XCTAssertEqual(historyLines.count, 1) // header only

        cleanupURLs(urls)
    }

    func testExportCSVIncludesTouchCountAndHistory() throws {
        let personId = UUID()
        let date1 = Date()
        let date2 = Date().addingTimeInterval(-86400)
        personRepo.people = [TestFactory.makePerson(id: personId, name: "Alice")]
        touchEventRepo.events = [
            TouchEvent(id: UUID(), personId: personId, at: date1, method: .call, notes: "First", timeOfDay: nil, createdAt: Date(), modifiedAt: Date()),
            TouchEvent(id: UUID(), personId: personId, at: date2, method: .text, notes: nil, timeOfDay: nil, createdAt: Date(), modifiedAt: Date())
        ]
        sut = SettingsViewModel(
            settingsRepository: settingsRepo,
            cadenceRepository: cadenceRepo,
            groupRepository: groupRepo,
            personRepository: personRepo,
            touchEventRepository: touchEventRepo
        )

        let urls = sut.exportContacts(format: .csv)

        // Contacts CSV: touch count = 2
        let contactsCSV = try String(contentsOf: urls[0], encoding: .utf8)
        let dataRow = contactsCSV.components(separatedBy: "\r\n")[1]
        XCTAssertTrue(dataRow.hasSuffix(",2"))

        // History CSV: 2 event rows + header
        let historyCSV = try String(contentsOf: urls[1], encoding: .utf8)
        let historyLines = historyCSV.components(separatedBy: "\r\n")
        XCTAssertEqual(historyLines.count, 3) // header + 2 events
        XCTAssertTrue(historyLines[1].contains("Alice"))
        XCTAssertTrue(historyLines[2].contains("Alice"))

        cleanupURLs(urls)
    }

    func testExportCSVIncludesStatusColumn() throws {
        let cadenceId = UUID()
        // Cadence with 7-day frequency, 2-day warning
        cadenceRepo.cadences = [TestFactory.makeCadence(id: cadenceId, name: "Weekly", frequencyDays: 7)]
        // Person last touched 30 days ago — should be overdue
        let person = TestFactory.makePerson(name: "Alice", cadenceId: cadenceId, lastTouchAt: Date().addingTimeInterval(-30 * 86400))
        personRepo.people = [person]
        sut = SettingsViewModel(
            settingsRepository: settingsRepo,
            cadenceRepository: cadenceRepo,
            groupRepository: groupRepo,
            personRepository: personRepo,
            touchEventRepository: touchEventRepo
        )

        let urls = sut.exportContacts(format: .csv)
        let contactsCSV = try String(contentsOf: urls[0], encoding: .utf8)
        let dataRow = contactsCSV.components(separatedBy: "\r\n")[1]
        XCTAssertTrue(dataRow.contains("Overdue"))

        cleanupURLs(urls)
    }

    func testExportCSVIncludesBirthdayColumn() throws {
        let person = TestFactory.makePerson(name: "Alice", birthday: Birthday(month: 3, day: 15, year: nil))
        personRepo.people = [person]
        sut = SettingsViewModel(
            settingsRepository: settingsRepo,
            cadenceRepository: cadenceRepo,
            groupRepository: groupRepo,
            personRepository: personRepo,
            touchEventRepository: touchEventRepo
        )

        let urls = sut.exportContacts(format: .csv)
        let contactsCSV = try String(contentsOf: urls[0], encoding: .utf8)
        let dataRow = contactsCSV.components(separatedBy: "\r\n")[1]
        XCTAssertTrue(dataRow.contains("Mar 15"))

        cleanupURLs(urls)
    }

    func testExportJSONFormatDefaultWorks() throws {
        personRepo.people = [TestFactory.makePerson(name: "Alice")]
        sut = SettingsViewModel(
            settingsRepository: settingsRepo,
            cadenceRepository: cadenceRepo,
            groupRepository: groupRepo,
            personRepository: personRepo,
            touchEventRepository: touchEventRepo
        )

        let urls = sut.exportContacts(format: .json)
        XCTAssertEqual(urls.count, 1)
        let data = try Data(contentsOf: urls[0])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExportData.self, from: data)
        XCTAssertEqual(decoded.people.count, 1)

        cleanupURLs(urls)
    }

    func testParseImportFileLegacyFormat() async throws {
        // Create a legacy-format JSON ([ExportPerson] array)
        let legacyPeople = [
            ExportPerson(
                id: UUID(),
                displayName: "Alice",
                cadenceId: nil,
                cadenceName: nil,
                groupIds: [],
                groupNames: [],
                lastTouchAt: nil,
                isPaused: false,
                createdAt: Date(),
                modifiedAt: Date(),
                touchEvents: nil,
                birthday: nil,
                birthdayNotificationsEnabled: nil
            )
        ]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(legacyPeople)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("legacy-test.json")
        try data.write(to: url, options: .atomic)

        let preview = await sut.parseImportFile(url: url)

        XCTAssertNotNil(preview)
        XCTAssertEqual(preview?.newPeople.count, 1)
        XCTAssertTrue(preview?.newCadences.isEmpty ?? false)
        XCTAssertTrue(preview?.newGroups.isEmpty ?? false)

        try? FileManager.default.removeItem(at: url)
    }

    func testParseImportFileNewFormatWithGroups() async throws {
        let cadenceId = UUID()
        let tagId = UUID()
        let exportData = ExportData(
            version: 2,
            exportedAt: Date(),
            cadences: [ExportCadence(id: cadenceId, name: "Custom Frequency", frequencyDays: 21, warningDays: 3, colorHex: nil, sortOrder: 0, isDefault: false)],
            groups: [ExportGroup(id: tagId, name: "Custom Cadence", colorHex: "#FF0000", sortOrder: 0)],
            people: [ExportPerson(
                id: UUID(),
                displayName: "Bob",
                cadenceId: cadenceId,
                cadenceName: "Custom Frequency",
                groupIds: [tagId],
                groupNames: ["Custom Cadence"],
                lastTouchAt: nil,
                isPaused: false,
                createdAt: Date(),
                modifiedAt: Date(),
                touchEvents: nil,
                birthday: nil,
                birthdayNotificationsEnabled: nil
            )]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(exportData)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("new-format-test.json")
        try data.write(to: url, options: .atomic)

        let preview = await sut.parseImportFile(url: url)

        XCTAssertNotNil(preview)
        XCTAssertEqual(preview?.newPeople.count, 1)
        XCTAssertEqual(preview?.newCadences.count, 1)
        XCTAssertEqual(preview?.newCadences.first?.name, "Custom Frequency")
        XCTAssertEqual(preview?.newGroups.count, 1)
        XCTAssertEqual(preview?.newGroups.first?.name, "Custom Cadence")

        try? FileManager.default.removeItem(at: url)
    }

    func testImportMergesGroupsByName() async throws {
        // Set up existing group "Weekly"
        let existingGroupId = UUID()
        cadenceRepo.cadences = [TestFactory.makeCadence(id: existingGroupId, name: "Weekly")]
        sut = SettingsViewModel(
            settingsRepository: settingsRepo,
            cadenceRepository: cadenceRepo,
            groupRepository: groupRepo,
            personRepository: personRepo,
            touchEventRepository: touchEventRepo
        )

        let importedGroupId = UUID()
        let exportData = ExportData(
            version: 2,
            exportedAt: Date(),
            cadences: [ExportCadence(id: importedGroupId, name: "weekly", frequencyDays: 7, warningDays: 2, colorHex: nil, sortOrder: 0, isDefault: true)],
            groups: [],
            people: [ExportPerson(
                id: UUID(),
                displayName: "Charlie",
                cadenceId: importedGroupId,
                cadenceName: "weekly",
                groupIds: [],
                groupNames: [],
                lastTouchAt: nil,
                isPaused: false,
                createdAt: Date(),
                modifiedAt: Date(),
                touchEvents: nil,
                birthday: nil,
                birthdayNotificationsEnabled: nil
            )]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(exportData)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("merge-test.json")
        try data.write(to: url, options: .atomic)

        let preview = await sut.parseImportFile(url: url)

        XCTAssertNotNil(preview)
        // "weekly" matches existing "Weekly" — no new group created
        XCTAssertTrue(preview?.newCadences.isEmpty ?? false)
        // The imported cadence ID should map to existing cadence
        XCTAssertEqual(preview?.cadenceIdMap[importedGroupId], existingGroupId)

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
        cadenceRepo.cadences = [
            TestFactory.makeCadence(name: "Weekly"),
            TestFactory.makeCadence(name: "Monthly"),
            TestFactory.makeCadence(name: "Quarterly")
        ]
        groupRepo.groups = [
            TestFactory.makeGroup(name: "Work"),
            TestFactory.makeGroup(name: "Family")
        ]
        personRepo.people = [
            TestFactory.makePerson(name: "Active"),
            TestFactory.makePerson(name: "Paused", isPaused: true)
        ]

        sut.load()

        XCTAssertEqual(sut.cadencesCount, 3)
        XCTAssertEqual(sut.groupsCount, 2)
        XCTAssertEqual(sut.pausedCount, 1)
    }

    // MARK: - Import Dedup (Name-Based Fallback)

    func testReimportByNameDoesNotCreateDuplicate() async throws {
        // Existing tracked person with unique name
        let existingId = UUID()
        personRepo.people = [TestFactory.makePerson(id: existingId, name: "Alice Smith")]
        sut = SettingsViewModel(
            settingsRepository: settingsRepo,
            cadenceRepository: cadenceRepo,
            groupRepository: groupRepo,
            personRepository: personRepo,
            touchEventRepository: touchEventRepo
        )

        // Import file has same name but different UUID (simulating re-export/re-import)
        let exportData = ExportData(
            version: 2,
            exportedAt: Date(),
            cadences: [],
            groups: [],
            people: [ExportPerson(
                id: UUID(), // Different UUID
                displayName: "Alice Smith",
                cadenceId: nil,
                cadenceName: nil,
                groupIds: [],
                groupNames: [],
                lastTouchAt: nil,
                isPaused: false,
                createdAt: Date(),
                modifiedAt: Date(),
                touchEvents: nil,
                birthday: nil,
                birthdayNotificationsEnabled: nil
            )]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(exportData)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dedup-name-test.json")
        try data.write(to: url, options: .atomic)

        let preview = await sut.parseImportFile(url: url)

        XCTAssertNotNil(preview)
        // Name-only fallback: single tracked person with name "Alice Smith" → auto-match
        XCTAssertTrue(preview?.newPeople.isEmpty ?? false, "Should NOT create new person — matched by name")
        XCTAssertEqual(preview?.updatedPeople.count, 1, "Should classify as updated person")
        XCTAssertEqual(preview?.remappedIds.values.first, existingId, "Should remap to existing person ID")

        try? FileManager.default.removeItem(at: url)
    }

    func testReimportWithDuplicateNamesCreatesNew() async throws {
        // Two tracked people with the same name
        personRepo.people = [
            TestFactory.makePerson(name: "John Smith"),
            TestFactory.makePerson(name: "John Smith")
        ]
        sut = SettingsViewModel(
            settingsRepository: settingsRepo,
            cadenceRepository: cadenceRepo,
            groupRepository: groupRepo,
            personRepository: personRepo,
            touchEventRepository: touchEventRepo
        )

        let exportData = ExportData(
            version: 2,
            exportedAt: Date(),
            cadences: [],
            groups: [],
            people: [ExportPerson(
                id: UUID(),
                displayName: "John Smith",
                cadenceId: nil,
                cadenceName: nil,
                groupIds: [],
                groupNames: [],
                lastTouchAt: nil,
                isPaused: false,
                createdAt: Date(),
                modifiedAt: Date(),
                touchEvents: nil,
                birthday: nil,
                birthdayNotificationsEnabled: nil
            )]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(exportData)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dedup-ambiguous-test.json")
        try data.write(to: url, options: .atomic)

        let preview = await sut.parseImportFile(url: url)

        XCTAssertNotNil(preview)
        // Two tracked "John Smith" and no CN match in test env → classified as new (not ambiguous,
        // because CN matching requires contacts access which tests don't have)
        XCTAssertEqual(preview?.newPeople.count, 1, "Ambiguous name without CN match → new contact")

        try? FileManager.default.removeItem(at: url)
    }

    func testReimportByUUIDMatchClassifiesAsUpdated() async throws {
        let existingId = UUID()
        personRepo.people = [TestFactory.makePerson(id: existingId, name: "Bob")]
        sut = SettingsViewModel(
            settingsRepository: settingsRepo,
            cadenceRepository: cadenceRepo,
            groupRepository: groupRepo,
            personRepository: personRepo,
            touchEventRepository: touchEventRepo
        )

        let exportData = ExportData(
            version: 2,
            exportedAt: Date(),
            cadences: [],
            groups: [],
            people: [ExportPerson(
                id: existingId, // Same UUID
                displayName: "Bob",
                cadenceId: nil,
                cadenceName: nil,
                groupIds: [],
                groupNames: [],
                lastTouchAt: nil,
                isPaused: false,
                createdAt: Date(),
                modifiedAt: Date(),
                touchEvents: nil,
                birthday: nil,
                birthdayNotificationsEnabled: nil
            )]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(exportData)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dedup-uuid-test.json")
        try data.write(to: url, options: .atomic)

        let preview = await sut.parseImportFile(url: url)

        XCTAssertNotNil(preview)
        XCTAssertTrue(preview?.newPeople.isEmpty ?? false)
        XCTAssertEqual(preview?.updatedPeople.count, 1, "UUID match → updated person")
        // No remapping needed for UUID match
        XCTAssertTrue(preview?.remappedIds.isEmpty ?? false)

        try? FileManager.default.removeItem(at: url)
    }

    func testReimportDoesNotCountExistingTouchEventsAsNew() async throws {
        let personId = UUID()
        let cal = Calendar.current
        let touchDate = cal.date(byAdding: .day, value: -3, to: Date())!

        // Existing tracked person with one touch event
        let person = TestFactory.makePerson(id: personId, name: "Alice Smith")
        personRepo.people = [person]

        let existingEvent = TouchEvent(
            id: UUID(),
            personId: personId,
            at: touchDate,
            method: .call,
            notes: "Caught up",
            timeOfDay: nil,
            createdAt: touchDate,
            modifiedAt: touchDate
        )
        touchEventRepo.events = [existingEvent]

        sut = SettingsViewModel(
            settingsRepository: settingsRepo,
            cadenceRepository: cadenceRepo,
            groupRepository: groupRepo,
            personRepository: personRepo,
            touchEventRepository: touchEventRepo
        )

        // Export file with same person (different UUID) and same event
        let exportData = ExportData(
            version: 2,
            exportedAt: Date(),
            cadences: [],
            groups: [],
            people: [ExportPerson(
                id: UUID(),
                displayName: "Alice Smith",
                cadenceId: nil,
                cadenceName: nil,
                groupIds: [],
                groupNames: [],
                lastTouchAt: touchDate,
                isPaused: false,
                createdAt: Date(),
                modifiedAt: Date(),
                touchEvents: [
                    ExportTouchEvent(id: UUID(), at: touchDate, method: "Call", notes: "Caught up")
                ],
                birthday: nil,
                birthdayNotificationsEnabled: nil
            )]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(exportData)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dedup-test.json")
        try data.write(to: url, options: .atomic)

        let preview = await sut.parseImportFile(url: url)

        XCTAssertNotNil(preview)
        XCTAssertEqual(preview?.touchEventCount, 1, "File contains 1 total event")
        XCTAssertEqual(preview?.newTouchEventCount, 0, "Event already exists — should not count as new")
        XCTAssertEqual(preview?.updatedPeople.count, 1, "Alice should match by name")

        try? FileManager.default.removeItem(at: url)
    }

    func testImportPreviewIncludesTouchEventCount() async throws {
        let exportData = ExportData(
            version: 2,
            exportedAt: Date(),
            cadences: [],
            groups: [],
            people: [ExportPerson(
                id: UUID(),
                displayName: "Eve",
                cadenceId: nil,
                cadenceName: nil,
                groupIds: [],
                groupNames: [],
                lastTouchAt: Date(),
                isPaused: false,
                createdAt: Date(),
                modifiedAt: Date(),
                touchEvents: [
                    ExportTouchEvent(id: UUID(), at: Date(), method: "call", notes: "Caught up"),
                    ExportTouchEvent(id: UUID(), at: Date(), method: "message", notes: nil)
                ],
                birthday: nil,
                birthdayNotificationsEnabled: nil
            )]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(exportData)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("events-count-test.json")
        try data.write(to: url, options: .atomic)

        let preview = await sut.parseImportFile(url: url)

        XCTAssertNotNil(preview)
        XCTAssertEqual(preview?.touchEventCount, 2)
        XCTAssertEqual(preview?.newTouchEventCount, 2, "New person — all events should be new")

        try? FileManager.default.removeItem(at: url)
    }
}
