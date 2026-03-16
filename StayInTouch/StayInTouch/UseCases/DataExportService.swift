//
//  DataExportService.swift
//  KeepInTouch
//
//  Handles JSON export of contacts, cadences, groups, and touch events.
//

import Foundation

struct DataExportService {
    let personRepository: PersonRepository
    let cadenceRepository: CadenceRepository
    let groupRepository: GroupRepository
    let touchEventRepository: TouchEventRepository

    func exportContacts() -> URL? {
        let people = personRepository.fetchAll()
        let cadences = cadenceRepository.fetchAll()
        let groups = groupRepository.fetchAll()

        let cadenceNameById = Dictionary(uniqueKeysWithValues: cadences.map { ($0.id, $0.name) })
        let groupNameById = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0.name) })

        let exportPeople = people.map { person in
            ExportPerson.from(
                person,
                groupName: cadenceNameById[person.cadenceId],
                tagNames: person.groupIds.compactMap { groupNameById[$0] },
                touchEvents: touchEventRepository.fetchAll(for: person.id)
            )
        }

        let exportData = ExportData(
            version: 2,
            exportedAt: Date(),
            groups: cadences.map { ExportCadence.from($0) },
            tags: groups.map { ExportGroup.from($0) },
            people: exportPeople
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(exportData) else { return nil }

        let filename = "keepintouch-export-\(ISO8601DateFormatter().string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
