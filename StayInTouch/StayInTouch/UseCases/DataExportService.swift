//
//  DataExportService.swift
//  KeepInTouch
//
//  Handles JSON export of contacts, groups, tags, and touch events.
//

import Foundation

struct DataExportService {
    let personRepository: PersonRepository
    let cadenceRepository: CadenceRepository
    let tagRepository: TagRepository
    let touchEventRepository: TouchEventRepository

    func exportContacts() -> URL? {
        let people = personRepository.fetchAll()
        let groups = cadenceRepository.fetchAll()
        let tags = tagRepository.fetchAll()

        let groupNameById = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0.name) })
        let tagNameById = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0.name) })

        let exportPeople = people.map { person in
            ExportPerson.from(
                person,
                groupName: groupNameById[person.cadenceId],
                tagNames: person.tagIds.compactMap { tagNameById[$0] },
                touchEvents: touchEventRepository.fetchAll(for: person.id)
            )
        }

        let exportData = ExportData(
            version: 2,
            exportedAt: Date(),
            groups: groups.map { ExportCadence.from($0) },
            tags: tags.map { ExportTag.from($0) },
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
