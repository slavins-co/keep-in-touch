//
//  DataExportService.swift
//  KeepInTouch
//
//  Handles JSON and CSV export of contacts, cadences, groups, and touch events.
//

import Foundation

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

    func exportCSV() -> [URL] {
        let rawPeople = personRepository.fetchAll()
        let cadences = cadenceRepository.fetchAll()
        let groups = groupRepository.fetchAll()

        let cadenceNameById = Dictionary(uniqueKeysWithValues: cadences.map { ($0.id, $0.name) })
        let groupNameById = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0.name) })
        let calculator = FrequencyCalculator()

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short

        let timestamp = ISO8601DateFormatter().string(from: Date())
        var urls: [URL] = []

        // Fetch touch events once per person, reuse for both CSVs
        var touchEventsByPersonId: [UUID: [TouchEvent]] = [:]
        for person in rawPeople {
            touchEventsByPersonId[person.id] = touchEventRepository.fetchAll(for: person.id)
        }

        // --- Contacts CSV ---
        var contactRows: [String] = []
        contactRows.append(csvRow(["Name", "Cadence", "Groups", "Status", "Birthday", "Last Touched", "Last Touch Method", "Paused", "Notes", "Touch Count"]))

        for person in rawPeople {
            let touchEvents = touchEventsByPersonId[person.id] ?? []
            let groupNames = person.groupIds.compactMap { groupNameById[$0] }.joined(separator: "; ")
            let status = calculator.status(for: person, in: cadences)
            let statusLabel: String
            switch status {
            case .onTrack: statusLabel = person.isPaused ? "" : "On Track"
            case .dueSoon: statusLabel = "Due Soon"
            case .overdue: statusLabel = "Overdue"
            case .unknown: statusLabel = ""
            }
            let lastTouchDate = person.lastTouchAt.map { dateFormatter.string(from: $0) } ?? ""
            let lastMethod = touchEvents.first.map { $0.method.rawValue } ?? ""
            let lastNotes = touchEvents.first?.notes ?? ""

            contactRows.append(csvRow([
                person.displayName,
                cadenceNameById[person.cadenceId] ?? "",
                groupNames,
                statusLabel,
                person.birthday?.formatted ?? "",
                lastTouchDate,
                lastMethod,
                person.isPaused ? "Yes" : "No",
                lastNotes,
                String(touchEvents.count)
            ]))
        }

        let contactsCSV = contactRows.joined(separator: "\r\n")
        if let data = contactsCSV.data(using: .utf8),
           let url = writeToTempFile(data: data, filename: "keepintouch-contacts-\(timestamp).csv") {
            urls.append(url)
        }

        // --- Touch History CSV ---
        var historyRows: [String] = []
        historyRows.append(csvRow(["Name", "Date", "Method", "Notes"]))

        var allEvents: [(name: String, event: TouchEvent)] = []
        for person in rawPeople {
            let events = touchEventsByPersonId[person.id] ?? []
            for event in events {
                allEvents.append((name: person.displayName, event: event))
            }
        }
        allEvents.sort { $0.event.at > $1.event.at }

        for entry in allEvents {
            historyRows.append(csvRow([
                entry.name,
                dateFormatter.string(from: entry.event.at),
                entry.event.method.rawValue,
                entry.event.notes ?? ""
            ]))
        }

        let historyCSV = historyRows.joined(separator: "\r\n")
        if let data = historyCSV.data(using: .utf8),
           let url = writeToTempFile(data: data, filename: "keepintouch-history-\(timestamp).csv") {
            urls.append(url)
        }

        return urls
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
