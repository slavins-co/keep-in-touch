//
//  DataImportServiceIntegrationTests.swift
//  KeepInTouchTests
//
//  Integration tests for the import pipeline using real CoreData repositories.
//

import CoreData
import XCTest
@testable import StayInTouch

final class DataImportServiceIntegrationTests: XCTestCase {

    private var context: NSManagedObjectContext!
    private var personRepo: CoreDataPersonRepository!
    private var groupRepo: CoreDataCadenceRepository!
    private var tagRepo: CoreDataTagRepository!
    private var touchRepo: CoreDataTouchEventRepository!
    private var sut: DataImportService!

    override func setUp() {
        super.setUp()
        let stack = CoreDataTestStack()
        context = stack.container.newBackgroundContext()
        personRepo = CoreDataPersonRepository(context: context)
        groupRepo = CoreDataCadenceRepository(context: context)
        tagRepo = CoreDataTagRepository(context: context)
        touchRepo = CoreDataTouchEventRepository(context: context)
        sut = DataImportService(
            personRepository: personRepo,
            cadenceRepository: groupRepo,
            tagRepository: tagRepo,
            touchEventRepository: touchRepo,
            backgroundContextProvider: { [unowned self] in self.context }
        )
    }

    override func tearDown() {
        sut = nil
        touchRepo = nil
        tagRepo = nil
        groupRepo = nil
        personRepo = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func writeExportJSON(_ exportData: ExportData) throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(exportData)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("import-test-\(UUID().uuidString).json")
        try data.write(to: url, options: .atomic)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func writeRawJSON(_ string: String) throws -> URL {
        let data = Data(string.utf8)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("import-test-\(UUID().uuidString).json")
        try data.write(to: url, options: .atomic)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    @discardableResult
    private func seedDefaultGroup(id: UUID = UUID(), name: String = "Weekly") throws -> Cadence {
        let group = TestFactory.makeGroup(id: id, name: name, frequencyDays: 7, isDefault: true)
        try groupRepo.save(group)
        return group
    }

    private func makeExportPerson(
        id: UUID = UUID(),
        name: String,
        cadenceId: UUID?,
        tagIds: [UUID] = [],
        lastTouchAt: Date? = nil,
        isPaused: Bool = false,
        touchEvents: [ExportTouchEvent]? = nil
    ) -> ExportPerson {
        let now = Date()
        return ExportPerson(
            id: id,
            displayName: name,
            cadenceId: cadenceId,
            groupName: nil,
            tagIds: tagIds,
            tagNames: [],
            lastTouchAt: lastTouchAt,
            isPaused: isPaused,
            createdAt: now,
            modifiedAt: now,
            touchEvents: touchEvents,
            birthday: nil,
            birthdayNotificationsEnabled: nil
        )
    }

    private func makeExportEvent(
        at date: Date,
        method: TouchMethod = .call,
        notes: String? = nil
    ) -> ExportTouchEvent {
        ExportTouchEvent(id: UUID(), at: date, method: method.rawValue, notes: notes)
    }

    // MARK: - Test 1: Happy Path

    func testHappyPath_importsAllEntities() async throws {
        try seedDefaultGroup()

        let groupA = UUID()
        let groupB = UUID()
        let tagId = UUID()
        let now = Date()

        let events1 = [
            makeExportEvent(at: now.addingTimeInterval(-86400 * 3), method: .call, notes: "Caught up"),
            makeExportEvent(at: now.addingTimeInterval(-86400 * 1), method: .text)
        ]
        let events2 = [
            makeExportEvent(at: now.addingTimeInterval(-86400 * 5), method: .email)
        ]
        let events3 = [
            makeExportEvent(at: now.addingTimeInterval(-86400 * 2), method: .irl),
            makeExportEvent(at: now.addingTimeInterval(-86400 * 7), method: .call)
        ]

        let exportData = ExportData(
            version: 2,
            exportedAt: now,
            groups: [
                ExportCadence(id: groupA, name: "Close Friends", frequencyDays: 3, warningDays: 1, colorHex: "#FF0000", sortOrder: 0, isDefault: false),
                ExportCadence(id: groupB, name: "Monthly", frequencyDays: 30, warningDays: 5, colorHex: nil, sortOrder: 1, isDefault: false)
            ],
            tags: [
                ExportTag(id: tagId, name: "Family", colorHex: "#00FF00", sortOrder: 0)
            ],
            people: [
                makeExportPerson(name: "Alice", cadenceId: groupA, tagIds: [tagId], touchEvents: events1),
                makeExportPerson(name: "Bob", cadenceId: groupB, touchEvents: events2),
                makeExportPerson(name: "Carol", cadenceId: groupA, touchEvents: events3)
            ]
        )

        let url = try writeExportJSON(exportData)
        let preview = await sut.parseImportFile(url: url)
        let previewValue = try XCTUnwrap(preview)

        XCTAssertEqual(previewValue.newPeople.count, 3)
        XCTAssertEqual(previewValue.newGroups.count, 2)
        XCTAssertEqual(previewValue.newTags.count, 1)
        XCTAssertEqual(previewValue.newTouchEventCount, 5)

        let result = await sut.executeImport(previewValue)

        XCTAssertEqual(result.totalPeople, 3)
        XCTAssertEqual(result.groupsCreated, 2)
        XCTAssertEqual(result.tagsCreated, 1)

        // Verify persistence via real repos
        let allPeople = personRepo.fetchAll()
        XCTAssertEqual(allPeople.count, 3, "All 3 people should be persisted")

        let allGroups = groupRepo.fetchAll()
        XCTAssertEqual(allGroups.count, 3, "Default + 2 imported groups")
        XCTAssertTrue(allGroups.contains(where: { $0.name == "Close Friends" }))
        XCTAssertTrue(allGroups.contains(where: { $0.name == "Monthly" }))

        let allTags = tagRepo.fetchAll()
        XCTAssertEqual(allTags.count, 1)
        XCTAssertEqual(allTags.first?.name, "Family")

        // Verify touch events total
        var totalEvents = 0
        for person in allPeople {
            totalEvents += touchRepo.fetchAll(for: person.id).count
        }
        XCTAssertEqual(totalEvents, 5, "All 5 touch events should be persisted")
    }

    // MARK: - Test 2: UUID Duplicate

    func testDuplicateUUID_updatesNotDuplicates() async throws {
        let cadenceId = try seedDefaultGroup().id
        let personId = UUID()
        let existingPerson = TestFactory.makePerson(id: personId, name: "Alice", cadenceId: cadenceId)
        try personRepo.save(existingPerson)

        let exportData = ExportData(
            version: 2,
            exportedAt: Date(),
            groups: [],
            tags: [],
            people: [
                makeExportPerson(id: personId, name: "Alice Updated", cadenceId: cadenceId)
            ]
        )

        let url = try writeExportJSON(exportData)
        let previewOpt = await sut.parseImportFile(url: url)
        let preview = try XCTUnwrap(previewOpt)

        XCTAssertEqual(preview.updatedPeople.count, 1, "Should classify as updated")
        XCTAssertTrue(preview.newPeople.isEmpty, "Should not be new")

        _ = await sut.executeImport(preview)

        let allPeople = personRepo.fetchAll()
        XCTAssertEqual(allPeople.count, 1, "Should update, not duplicate")

        let updated = try XCTUnwrap(personRepo.fetch(id: personId))
        XCTAssertEqual(updated.displayName, "Alice Updated")
    }

    // MARK: - Test 3: Name-Only Match

    func testNameOnlyMatch_updatesExistingPerson() async throws {
        let cadenceId = try seedDefaultGroup().id
        let existingId = UUID()
        let existingPerson = TestFactory.makePerson(id: existingId, name: "Sarah Chen", cadenceId: cadenceId)
        try personRepo.save(existingPerson)

        // Different UUID, same name
        let exportData = ExportData(
            version: 2,
            exportedAt: Date(),
            groups: [],
            tags: [],
            people: [
                makeExportPerson(id: UUID(), name: "Sarah Chen", cadenceId: cadenceId)
            ]
        )

        let url = try writeExportJSON(exportData)
        let previewOpt = await sut.parseImportFile(url: url)
        let preview = try XCTUnwrap(previewOpt)

        XCTAssertEqual(preview.updatedPeople.count, 1, "Name-only match should classify as updated")
        XCTAssertTrue(preview.newPeople.isEmpty)
        XCTAssertNotNil(preview.remappedIds.values.first, "Should remap to existing person")

        _ = await sut.executeImport(preview)

        XCTAssertEqual(personRepo.fetchAll().count, 1, "Should not create duplicate")
    }

    // MARK: - Test 4: Touch Event Dedup

    func testTouchEventDedup_skipsExistingEvents() async throws {
        let cadenceId = try seedDefaultGroup().id
        let personId = UUID()
        let person = TestFactory.makePerson(id: personId, name: "Dave", cadenceId: cadenceId)
        try personRepo.save(person)

        let threeDaysAgo = Calendar.current.startOfDay(for: Date()).addingTimeInterval(-86400 * 3 + 3600)
        let fiveDaysAgo = Calendar.current.startOfDay(for: Date()).addingTimeInterval(-86400 * 5 + 3600)
        let oneDayAgo = Calendar.current.startOfDay(for: Date()).addingTimeInterval(-86400 * 1 + 3600)

        // Seed existing events
        try touchRepo.save(TestFactory.makeTouchEvent(personId: personId, at: threeDaysAgo, method: .call, notes: "Hi"))
        try touchRepo.save(TestFactory.makeTouchEvent(personId: personId, at: fiveDaysAgo, method: .text, notes: nil))

        XCTAssertEqual(touchRepo.fetchAll(for: personId).count, 2)

        let exportData = ExportData(
            version: 2,
            exportedAt: Date(),
            groups: [],
            tags: [],
            people: [
                makeExportPerson(
                    id: personId,
                    name: "Dave",
                    cadenceId: cadenceId,
                    touchEvents: [
                        makeExportEvent(at: threeDaysAgo, method: .call, notes: "Hi"),   // duplicate
                        makeExportEvent(at: fiveDaysAgo, method: .text, notes: nil),     // duplicate
                        makeExportEvent(at: oneDayAgo, method: .email, notes: "New")     // genuinely new
                    ]
                )
            ]
        )

        let url = try writeExportJSON(exportData)
        let previewOpt = await sut.parseImportFile(url: url)
        let preview = try XCTUnwrap(previewOpt)

        XCTAssertEqual(preview.newTouchEventCount, 1, "Only the email event should be new")

        _ = await sut.executeImport(preview)

        let allEvents = touchRepo.fetchAll(for: personId)
        XCTAssertEqual(allEvents.count, 3, "2 existing + 1 new = 3 total")
    }

    // MARK: - Test 5: Malformed JSON

    func testMalformedJSON_returnsNilPreview() async throws {
        let url = try writeRawJSON("this is not json at all {{{")

        let preview = await sut.parseImportFile(url: url)

        XCTAssertNil(preview, "Malformed JSON should return nil")
        XCTAssertTrue(personRepo.fetchAll().isEmpty, "No data should be persisted")
        XCTAssertEqual(groupRepo.fetchAll().count, 0)
    }

    // MARK: - Test 6: Missing Required Fields

    func testMissingRequiredFields_returnsNilPreview() async throws {
        // Valid JSON but not a valid ExportData or [ExportPerson]
        let url = try writeRawJSON("""
        {"version": 2, "someRandomField": "value"}
        """)

        let preview = await sut.parseImportFile(url: url)

        XCTAssertNil(preview, "Invalid structure should return nil")
    }

    // MARK: - Test 7: Ambiguous Names

    func testAmbiguousNames_createsNewPerson() async throws {
        let cadenceId = try seedDefaultGroup().id

        // Two tracked people with the same name
        try personRepo.save(TestFactory.makePerson(name: "John Smith", cadenceId: cadenceId))
        try personRepo.save(TestFactory.makePerson(name: "John Smith", cadenceId: cadenceId))

        XCTAssertEqual(personRepo.fetchAll().count, 2)

        let exportData = ExportData(
            version: 2,
            exportedAt: Date(),
            groups: [],
            tags: [],
            people: [
                makeExportPerson(name: "John Smith", cadenceId: cadenceId)
            ]
        )

        let url = try writeExportJSON(exportData)
        let previewOpt = await sut.parseImportFile(url: url)
        let preview = try XCTUnwrap(previewOpt)

        // Without CN access, multiple name matches → falls through to new person
        XCTAssertEqual(preview.newPeople.count, 1, "Ambiguous name should create new person")
        XCTAssertTrue(preview.updatedPeople.isEmpty)

        _ = await sut.executeImport(preview)

        XCTAssertEqual(personRepo.fetchAll().count, 3, "2 original + 1 new")
    }

    // MARK: - Test 8: Cadence Merging

    func testGroupMerging_deduplicatesByName() async throws {
        let defaultGroup = try seedDefaultGroup(name: "Weekly")

        let exportGroupId = UUID()
        let exportData = ExportData(
            version: 2,
            exportedAt: Date(),
            groups: [
                ExportCadence(id: exportGroupId, name: "weekly", frequencyDays: 7, warningDays: 2, colorHex: nil, sortOrder: 0, isDefault: false)
            ],
            tags: [],
            people: [
                makeExportPerson(name: "Eve", cadenceId: exportGroupId)
            ]
        )

        let url = try writeExportJSON(exportData)
        let previewOpt = await sut.parseImportFile(url: url)
        let preview = try XCTUnwrap(previewOpt)

        XCTAssertTrue(preview.newGroups.isEmpty, "Cadence should merge by name (case-insensitive)")
        XCTAssertEqual(preview.groupIdMap[exportGroupId], defaultGroup.id, "Should map to existing group")

        _ = await sut.executeImport(preview)

        XCTAssertEqual(groupRepo.fetchAll().count, 1, "No duplicate group")

        let importedPerson = personRepo.fetchAll().first
        XCTAssertEqual(importedPerson?.cadenceId, defaultGroup.id, "Person should be assigned to existing group")
    }

    // MARK: - Test 9: Denormalized Fields

    func testDenormalizedFields_updatedFromImportedEvents() async throws {
        try seedDefaultGroup()

        let fiveDaysAgo = Date().addingTimeInterval(-86400 * 5)
        let oneDayAgo = Date().addingTimeInterval(-86400 * 1)

        let exportData = ExportData(
            version: 2,
            exportedAt: Date(),
            groups: [],
            tags: [],
            people: [
                makeExportPerson(
                    name: "Fiona",
                    cadenceId: nil,
                    touchEvents: [
                        makeExportEvent(at: fiveDaysAgo, method: .call),
                        makeExportEvent(at: oneDayAgo, method: .email, notes: "Latest")
                    ]
                )
            ]
        )

        let url = try writeExportJSON(exportData)
        let previewOpt = await sut.parseImportFile(url: url)
        let preview = try XCTUnwrap(previewOpt)
        _ = await sut.executeImport(preview)

        let person = try XCTUnwrap(personRepo.fetchAll().first)

        // lastTouchAt should reflect the most recent event
        XCTAssertNotNil(person.lastTouchAt)
        if let lastTouch = person.lastTouchAt {
            let daysBetween = Calendar.current.dateComponents([.day], from: lastTouch, to: oneDayAgo).day ?? 99
            XCTAssertEqual(daysBetween, 0, "lastTouchAt should match the most recent imported event")
        }
        XCTAssertEqual(person.lastTouchMethod, .email, "lastTouchMethod should match most recent event")
        XCTAssertEqual(person.lastTouchNotes, "Latest")
    }

    // MARK: - Test 10: Empty Display Name

    func testEmptyDisplayName_skipped() async throws {
        try seedDefaultGroup()

        let exportData = ExportData(
            version: 2,
            exportedAt: Date(),
            groups: [],
            tags: [],
            people: [
                makeExportPerson(name: "   ", cadenceId: nil),   // whitespace-only
                makeExportPerson(name: "Valid Person", cadenceId: nil)
            ]
        )

        let url = try writeExportJSON(exportData)
        let previewOpt = await sut.parseImportFile(url: url)
        let preview = try XCTUnwrap(previewOpt)

        XCTAssertEqual(preview.skippedCount, 1, "Whitespace name should be skipped")
        XCTAssertEqual(preview.newPeople.count, 1, "Only valid person should be included")
        XCTAssertEqual(preview.newPeople.first?.displayName, "Valid Person")
    }
}
