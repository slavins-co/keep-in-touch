//
//  DataExportService.swift
//  KeepInTouch
//
//  Handles JSON and CSV export of contacts, cadences, groups, and touch events.
//

import Foundation

enum ExportFormat: String, CaseIterable {
    case json
    case csv
}

struct DataExportService {
    let personRepository: PersonRepository
    let cadenceRepository: CadenceRepository
    let groupRepository: GroupRepository
    let touchEventRepository: TouchEventRepository

    func exportContacts() -> URL? {
        exportJSON()
    }

    func exportJSON() -> URL? {
        let (people, cadences, groups) = fetchExportData()

        let exportData = ExportData(
            version: 3,
            exportedAt: Date(),
            cadences: cadences.map { ExportCadence.from($0) },
            groups: groups.map { ExportGroup.from($0) },
            people: people
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(exportData) else { return nil }

        let filename = "keepintouch-export-\(ISO8601DateFormatter().string(from: Date())).json"
        return writeToTempFile(data: data, filename: filename)
    }

    func exportCSV() -> URL? {
        let (people, _, _) = fetchExportData()

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short

        var rows: [String] = []
        rows.append(csvRow(["Name", "Cadence", "Groups", "Last Touched", "Last Touch Method", "Paused", "Notes", "Touch Count"]))

        for person in people {
            let touchCount = person.touchEvents?.count ?? 0
            let lastTouchDate = person.lastTouchAt.map { dateFormatter.string(from: $0) } ?? ""
            let lastMethod = person.touchEvents?.first.map { $0.method } ?? ""
            let lastNotes = person.touchEvents?.first?.notes ?? ""
            let groups = person.groupNames.joined(separator: "; ")

            rows.append(csvRow([
                person.displayName,
                person.cadenceName ?? "",
                groups,
                lastTouchDate,
                lastMethod,
                person.isPaused ? "Yes" : "No",
                lastNotes,
                String(touchCount)
            ]))
        }

        let csvString = rows.joined(separator: "\r\n")
        guard let data = csvString.data(using: .utf8) else { return nil }

        let filename = "keepintouch-export-\(ISO8601DateFormatter().string(from: Date())).csv"
        return writeToTempFile(data: data, filename: filename)
    }

    // MARK: - Private

    private func fetchExportData() -> ([ExportPerson], [Cadence], [Group]) {
        let people = personRepository.fetchAll()
        let cadences = cadenceRepository.fetchAll()
        let groups = groupRepository.fetchAll()

        let cadenceNameById = Dictionary(uniqueKeysWithValues: cadences.map { ($0.id, $0.name) })
        let groupNameById = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0.name) })

        let exportPeople = people.map { person in
            ExportPerson.from(
                person,
                cadenceName: cadenceNameById[person.cadenceId],
                groupNames: person.groupIds.compactMap { groupNameById[$0] },
                touchEvents: touchEventRepository.fetchAll(for: person.id)
            )
        }

        return (exportPeople, cadences, groups)
    }

    private func writeToTempFile(data: Data, filename: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    /// RFC 4180 CSV row: escape fields containing commas, quotes, or newlines.
    private func csvRow(_ fields: [String]) -> String {
        fields.map { field in
            if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
                return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            return field
        }.joined(separator: ",")
    }
}
