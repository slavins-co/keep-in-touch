//
//  ExportModelsBackwardCompatTests.swift
//  KeepInTouchTests
//
//  Tests backward compatibility for JSON import across format versions.
//  v2 used "groups" for cadences and "tags" for groups.
//  v3 uses "cadences" for cadences and "groups" for groups.
//

import XCTest
@testable import StayInTouch

final class ExportModelsBackwardCompatTests: XCTestCase {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let fixedDate = "2026-03-01T12:00:00Z"

    // MARK: - ExportData: v2 → v3 Backward Compat

    func testV2Format_decodesGroupsAsCadencesAndTagsAsGroups() throws {
        let json = """
        {
            "version": 2,
            "exportedAt": "\(fixedDate)",
            "groups": [
                {"id": "11111111-1111-1111-1111-111111111111", "name": "Weekly", "frequencyDays": 7, "warningDays": 2, "sortOrder": 0, "isDefault": true}
            ],
            "tags": [
                {"id": "22222222-2222-2222-2222-222222222222", "name": "Family", "colorHex": "#FF0000", "sortOrder": 0}
            ],
            "people": []
        }
        """

        let data = try decoder.decode(ExportData.self, from: Data(json.utf8))

        XCTAssertEqual(data.version, 2)
        XCTAssertEqual(data.cadences.count, 1, "v2 'groups' should decode as cadences")
        XCTAssertEqual(data.cadences.first?.name, "Weekly")
        XCTAssertEqual(data.cadences.first?.frequencyDays, 7)
        XCTAssertEqual(data.groups.count, 1, "v2 'tags' should decode as groups")
        XCTAssertEqual(data.groups.first?.name, "Family")
    }

    func testV3Format_decodesCadencesAndGroupsDirectly() throws {
        let json = """
        {
            "version": 3,
            "exportedAt": "\(fixedDate)",
            "cadences": [
                {"id": "11111111-1111-1111-1111-111111111111", "name": "Monthly", "frequencyDays": 30, "warningDays": 5, "sortOrder": 0, "isDefault": false}
            ],
            "groups": [
                {"id": "22222222-2222-2222-2222-222222222222", "name": "Work", "colorHex": "#0000FF", "sortOrder": 0}
            ],
            "people": []
        }
        """

        let data = try decoder.decode(ExportData.self, from: Data(json.utf8))

        XCTAssertEqual(data.version, 3)
        XCTAssertEqual(data.cadences.count, 1)
        XCTAssertEqual(data.cadences.first?.name, "Monthly")
        XCTAssertEqual(data.groups.count, 1)
        XCTAssertEqual(data.groups.first?.name, "Work")
    }

    func testV2Format_missingTagsKey_decodesEmptyGroups() throws {
        let json = """
        {
            "version": 2,
            "exportedAt": "\(fixedDate)",
            "groups": [
                {"id": "11111111-1111-1111-1111-111111111111", "name": "Weekly", "frequencyDays": 7, "warningDays": 2, "sortOrder": 0, "isDefault": true}
            ],
            "people": []
        }
        """

        let data = try decoder.decode(ExportData.self, from: Data(json.utf8))

        XCTAssertEqual(data.cadences.count, 1, "v2 'groups' should still decode as cadences")
        XCTAssertTrue(data.groups.isEmpty, "Missing 'tags' key should produce empty groups")
    }

    func testV3Format_encodesWithNewKeyNames() throws {
        let exportData = ExportData(
            version: 3,
            exportedAt: ISO8601DateFormatter().date(from: fixedDate)!,
            cadences: [ExportCadence(id: UUID(), name: "Weekly", frequencyDays: 7, warningDays: 2, colorHex: nil, sortOrder: 0, isDefault: true)],
            groups: [ExportGroup(id: UUID(), name: "Friends", colorHex: "#00FF00", sortOrder: 0)],
            people: []
        )

        let jsonData = try encoder.encode(exportData)
        let dict = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]

        XCTAssertNotNil(dict["cadences"], "v3 should encode with 'cadences' key")
        XCTAssertNotNil(dict["groups"], "v3 should encode with 'groups' key")
        XCTAssertNil(dict["tags"], "v3 should not encode a 'tags' key")
    }

    func testV3RoundTrip_preservesAllData() throws {
        let cadenceId = UUID()
        let groupId = UUID()
        let original = ExportData(
            version: 3,
            exportedAt: ISO8601DateFormatter().date(from: fixedDate)!,
            cadences: [ExportCadence(id: cadenceId, name: "Biweekly", frequencyDays: 14, warningDays: 3, colorHex: "#ABC123", sortOrder: 1, isDefault: false)],
            groups: [ExportGroup(id: groupId, name: "Coworkers", colorHex: "#DEF456", sortOrder: 2)],
            people: []
        )

        let jsonData = try encoder.encode(original)
        let decoded = try decoder.decode(ExportData.self, from: jsonData)

        XCTAssertEqual(decoded.cadences.count, 1)
        XCTAssertEqual(decoded.cadences.first?.id, cadenceId)
        XCTAssertEqual(decoded.cadences.first?.name, "Biweekly")
        XCTAssertEqual(decoded.cadences.first?.frequencyDays, 14)
        XCTAssertEqual(decoded.cadences.first?.colorHex, "#ABC123")
        XCTAssertEqual(decoded.groups.count, 1)
        XCTAssertEqual(decoded.groups.first?.id, groupId)
        XCTAssertEqual(decoded.groups.first?.name, "Coworkers")
    }

    // MARK: - ExportPerson: Legacy Key Backward Compat

    func testV2Person_decodesGroupIdAsCadenceId() throws {
        let cadenceId = UUID()
        let json = """
        {
            "id": "33333333-3333-3333-3333-333333333333",
            "displayName": "Alice",
            "groupId": "\(cadenceId.uuidString)",
            "groupName": "Weekly",
            "tagIds": ["44444444-4444-4444-4444-444444444444"],
            "tagNames": ["Family"],
            "isPaused": false,
            "createdAt": "\(fixedDate)",
            "modifiedAt": "\(fixedDate)"
        }
        """

        let person = try decoder.decode(ExportPerson.self, from: Data(json.utf8))

        XCTAssertEqual(person.cadenceId, cadenceId, "v2 'groupId' should map to cadenceId")
        XCTAssertEqual(person.cadenceName, "Weekly", "v2 'groupName' should map to cadenceName")
        XCTAssertEqual(person.groupIds.count, 1, "v2 'tagIds' should map to groupIds")
        XCTAssertEqual(person.groupNames, ["Family"], "v2 'tagNames' should map to groupNames")
    }

    func testV3Person_decodesNewKeysDirectly() throws {
        let cadenceId = UUID()
        let groupId = UUID()
        let json = """
        {
            "id": "33333333-3333-3333-3333-333333333333",
            "displayName": "Bob",
            "cadenceId": "\(cadenceId.uuidString)",
            "cadenceName": "Monthly",
            "groupIds": ["\(groupId.uuidString)"],
            "groupNames": ["Work"],
            "isPaused": false,
            "createdAt": "\(fixedDate)",
            "modifiedAt": "\(fixedDate)"
        }
        """

        let person = try decoder.decode(ExportPerson.self, from: Data(json.utf8))

        XCTAssertEqual(person.cadenceId, cadenceId)
        XCTAssertEqual(person.cadenceName, "Monthly")
        XCTAssertEqual(person.groupIds, [groupId])
        XCTAssertEqual(person.groupNames, ["Work"])
    }

    func testV3PersonKeysTakePrecedenceOverLegacy() throws {
        let newCadenceId = UUID()
        let legacyCadenceId = UUID()
        let json = """
        {
            "id": "33333333-3333-3333-3333-333333333333",
            "displayName": "Carol",
            "cadenceId": "\(newCadenceId.uuidString)",
            "groupId": "\(legacyCadenceId.uuidString)",
            "cadenceName": "New",
            "groupName": "Old",
            "groupIds": ["55555555-5555-5555-5555-555555555555"],
            "tagIds": ["66666666-6666-6666-6666-666666666666"],
            "groupNames": ["NewGroup"],
            "tagNames": ["OldTag"],
            "isPaused": false,
            "createdAt": "\(fixedDate)",
            "modifiedAt": "\(fixedDate)"
        }
        """

        let person = try decoder.decode(ExportPerson.self, from: Data(json.utf8))

        XCTAssertEqual(person.cadenceId, newCadenceId, "v3 'cadenceId' should take precedence over legacy 'groupId'")
        XCTAssertEqual(person.cadenceName, "New", "v3 'cadenceName' should take precedence over legacy 'groupName'")
        XCTAssertEqual(person.groupIds.first?.uuidString, "55555555-5555-5555-5555-555555555555",
                        "v3 'groupIds' should take precedence over legacy 'tagIds'")
        XCTAssertEqual(person.groupNames, ["NewGroup"], "v3 'groupNames' should take precedence over legacy 'tagNames'")
    }
}
