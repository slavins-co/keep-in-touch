//
//  DataImportService.swift
//  KeepInTouch
//
//  Handles JSON import parsing, execution, and post-import contact matching.
//

import Foundation
import CoreData
import Contacts

struct DataImportService {
    let personRepository: PersonRepository
    let cadenceRepository: CadenceRepository
    let tagRepository: TagRepository
    let touchEventRepository: TouchEventRepository
    var backgroundContextProvider: (() -> NSManagedObjectContext)? = nil

    static func touchEventDedupKey(personId: UUID, date: Date, method: TouchMethod, notes: String?, calendar: Calendar) -> String {
        let dayKey = Int(calendar.startOfDay(for: date).timeIntervalSince1970)
        let notesKey = (notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(personId)-\(dayKey)-\(method.rawValue)-\(notesKey)"
    }

    func parseImportFile(url: URL) async -> ImportPreview? {
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Try new format first, fall back to legacy [ExportPerson] array
        let importedPeople: [ExportPerson]
        let importedGroups: [ExportCadence]
        let importedTags: [ExportTag]

        if let exportData = try? decoder.decode(ExportData.self, from: data) {
            importedPeople = exportData.people
            importedGroups = exportData.groups
            importedTags = exportData.tags
        } else if let legacyPeople = try? decoder.decode([ExportPerson].self, from: data) {
            importedPeople = legacyPeople
            importedGroups = []
            importedTags = []
        } else {
            return nil
        }

        // --- Cadence merge: match by normalized name, skip duplicates ---
        let existingGroups = cadenceRepository.fetchAll()
        let existingGroupsByName = Dictionary(
            grouping: existingGroups,
            by: { $0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        )
        var groupIdMap: [UUID: UUID] = [:]
        var newGroups: [ExportCadence] = []

        for exportGroup in importedGroups {
            let normalized = exportGroup.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if let existing = existingGroupsByName[normalized]?.first {
                groupIdMap[exportGroup.id] = existing.id
            } else {
                let newId = UUID()
                groupIdMap[exportGroup.id] = newId
                newGroups.append(exportGroup)
            }
        }
        // Pass through any existing group IDs not in the export's group list
        for group in existingGroups {
            if groupIdMap[group.id] == nil {
                groupIdMap[group.id] = group.id
            }
        }

        // --- Tag merge: same logic ---
        let existingTags = tagRepository.fetchAll()
        let existingTagsByName = Dictionary(
            grouping: existingTags,
            by: { $0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        )
        var tagIdMap: [UUID: UUID] = [:]
        var newTags: [ExportTag] = []

        for exportTag in importedTags {
            let normalized = exportTag.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if let existing = existingTagsByName[normalized]?.first {
                tagIdMap[exportTag.id] = existing.id
            } else {
                let newId = UUID()
                tagIdMap[exportTag.id] = newId
                newTags.append(exportTag)
            }
        }
        for tag in existingTags {
            if tagIdMap[tag.id] == nil {
                tagIdMap[tag.id] = tag.id
            }
        }

        // --- People classification ---
        // Never trust cnIdentifier from external files — use address book as trusted intermediary
        let allExistingPeople = personRepository.fetchAll()
        let existingById = Dictionary(uniqueKeysWithValues: allExistingPeople.map { ($0.id, $0) })

        // CN-based dedup: build lookup of tracked people by their CNContact identifier
        let existingByCNId: [String: Person] = Dictionary(
            allExistingPeople.compactMap { p in
                guard let cn = p.cnIdentifier else { return nil }
                return (cn, p)
            },
            uniquingKeysWith: { first, _ in first }
        )

        // Fetch device address book contacts: normalized name → [cnIdentifier]
        // Run on background thread to avoid blocking main thread for large contact lists
        let hasContactsAccess: Bool = {
            switch CNContactStore.authorizationStatus(for: .contacts) {
            case .authorized, .limited: return true
            default: return false
            }
        }()
        let deviceContactsByName: [String: [String]] = await Task.detached {
            guard hasContactsAccess else {
                return [:]
            }
            var result: [String: [String]] = [:]
            let store = CNContactStore()
            let keys: [CNKeyDescriptor] = [
                CNContactIdentifierKey as CNKeyDescriptor,
                CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                CNContactOrganizationNameKey as CNKeyDescriptor
            ]
            let request = CNContactFetchRequest(keysToFetch: keys)
            try? store.enumerateContacts(with: request) { contact, _ in
                let name = CNContactFormatter.string(from: contact, style: .fullName)
                    ?? contact.organizationName
                let normalized = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalized.isEmpty else { return }
                result[normalized, default: []].append(contact.identifier)
            }
            return result
        }.value

        // Name-only fallback for contacts not in address book
        let existingTrackedByName = Dictionary(
            grouping: allExistingPeople.filter { $0.isTracked },
            by: { $0.displayName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        )

        var newPeople: [ExportPerson] = []
        var updatedPeople: [ExportPerson] = []
        var remappedIds: [UUID: UUID] = [:]
        var ambiguousPeople: [(export: ExportPerson, candidates: [Person])] = []
        var skipped = 0
        var touchEventCount = 0

        for person in importedPeople {
            guard !person.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                skipped += 1
                continue
            }
            let normalizedName = person.displayName.lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if existingById[person.id] != nil {
                // 1. UUID match — same app/DB
                updatedPeople.append(person)
            } else {
                // 2. CN match: find device contacts with this name, filter to tracked
                let cnIds = deviceContactsByName[normalizedName] ?? []
                let trackedMatches = cnIds.compactMap { existingByCNId[$0] }
                    .filter { existingById[$0.id] != nil }
                let uniqueMatches = Dictionary(grouping: trackedMatches, by: { $0.id })
                    .values.compactMap(\.first)

                if uniqueMatches.count == 1, let match = uniqueMatches.first {
                    // Single tracked match via address book → auto-match
                    updatedPeople.append(person)
                    remappedIds[person.id] = match.id
                } else if uniqueMatches.count > 1 {
                    // Multiple tracked matches → user must disambiguate
                    ambiguousPeople.append((export: person, candidates: uniqueMatches))
                } else if let nameMatches = existingTrackedByName[normalizedName],
                          nameMatches.count == 1, let match = nameMatches.first {
                    // 3. Name-only fallback (contact not in address book)
                    updatedPeople.append(person)
                    remappedIds[person.id] = match.id
                } else {
                    // 4. No match → new contact
                    newPeople.append(person)
                }
            }
            touchEventCount += person.touchEvents?.count ?? 0
        }

        // Compute new vs existing touch events for accurate preview
        let calendar = Calendar.current
        var existingEventKeys: Set<String> = []

        // Build keys for all matched people (updatedPeople + ambiguousPeople)
        let matchedPeople = updatedPeople + ambiguousPeople.map(\.export)
        for exportPerson in matchedPeople {
            let actualPersonId = remappedIds[exportPerson.id] ?? exportPerson.id
            guard existingById[actualPersonId] != nil else { continue }
            let existing = touchEventRepository.fetchAll(for: actualPersonId)
            for e in existing {
                existingEventKeys.insert(Self.touchEventDedupKey(personId: actualPersonId, date: e.at, method: e.method, notes: e.notes, calendar: calendar))
            }
        }

        var newTouchEventCount = 0
        for exportPerson in matchedPeople {
            guard let events = exportPerson.touchEvents else { continue }
            let actualPersonId = remappedIds[exportPerson.id] ?? exportPerson.id
            for event in events {
                let method = TouchMethod(rawValue: event.method) ?? .other
                let key = Self.touchEventDedupKey(personId: actualPersonId, date: event.at, method: method, notes: event.notes, calendar: calendar)
                if !existingEventKeys.contains(key) {
                    newTouchEventCount += 1
                    existingEventKeys.insert(key)
                }
            }
        }
        // All events from new people are always new
        for exportPerson in newPeople {
            newTouchEventCount += exportPerson.touchEvents?.count ?? 0
        }

        return ImportPreview(
            newPeople: newPeople,
            updatedPeople: updatedPeople,
            skippedCount: skipped,
            touchEventCount: touchEventCount,
            newTouchEventCount: newTouchEventCount,
            newGroups: newGroups,
            newTags: newTags,
            groupIdMap: groupIdMap,
            tagIdMap: tagIdMap,
            remappedIds: remappedIds,
            ambiguousPeople: ambiguousPeople
        )
    }

    func executeImport(_ preview: ImportPreview) async -> ImportResult {
        var importedNewPeople: [(id: UUID, displayName: String)] = []

        let backgroundContext = backgroundContextProvider?() ?? CoreDataStack.shared.newBackgroundContext()
        await backgroundContext.perform {
            let peopleRepo = CoreDataPersonRepository(context: backgroundContext)
            let touchRepo = CoreDataTouchEventRepository(context: backgroundContext)
            let groupRepo = CoreDataCadenceRepository(context: backgroundContext)
            let tagRepo = CoreDataTagRepository(context: backgroundContext)

            let now = Date()

            // 1. Create new groups from import (batch save)
            let existingGroupCount = groupRepo.fetchAll().count
            var groupsToSave: [Cadence] = []
            for (index, exportGroup) in preview.newGroups.enumerated() {
                guard let newId = preview.groupIdMap[exportGroup.id] else { continue }
                groupsToSave.append(Cadence(
                    id: newId,
                    name: exportGroup.name,
                    frequencyDays: exportGroup.frequencyDays,
                    warningDays: exportGroup.warningDays,
                    colorHex: exportGroup.colorHex,
                    isDefault: false,
                    sortOrder: existingGroupCount + index,
                    createdAt: now,
                    modifiedAt: now
                ))
            }
            if !groupsToSave.isEmpty {
                do {
                    try groupRepo.batchSave(groupsToSave)
                } catch {
                    AppLogger.logError(error, category: AppLogger.viewModel, context: "DataImportService.executeImport.groups")
                }
            }

            // 2. Create new tags from import (batch save)
            let existingTagCount = tagRepo.fetchAll().count
            var tagsToSave: [Tag] = []
            for (index, exportTag) in preview.newTags.enumerated() {
                guard let newId = preview.tagIdMap[exportTag.id] else { continue }
                tagsToSave.append(Tag(
                    id: newId,
                    name: exportTag.name,
                    colorHex: exportTag.colorHex,
                    sortOrder: existingTagCount + index,
                    createdAt: now,
                    modifiedAt: now
                ))
            }
            if !tagsToSave.isEmpty {
                do {
                    try tagRepo.batchSave(tagsToSave)
                } catch {
                    AppLogger.logError(error, category: AppLogger.viewModel, context: "DataImportService.executeImport.tags")
                }
            }

            // 3. Refresh valid group/tag IDs after creation
            let allGroups = groupRepo.fetchAll()
            let defaultGroupId = allGroups.first(where: { $0.isDefault })?.id ?? allGroups.first?.id ?? UUID()
            let validGroupIds = Set(allGroups.map { $0.id })

            // Only match by internal UUID — never trust cnIdentifier from external files
            let existingById = Dictionary(uniqueKeysWithValues: peopleRepo.fetchAll().map { ($0.id, $0) })
            let existingCount = peopleRepo.fetchTracked(includePaused: true).count
            var sortOrder = existingCount
            let assignGroup = AssignCadenceUseCase(referenceDate: now)

            var personsToSave: [Person] = []
            var importedIdMap: [UUID: UUID] = [:]

            // 4. New people — remap cadenceId and tagIds
            for exportPerson in preview.newPeople {
                let newId = UUID()
                importedIdMap[exportPerson.id] = newId

                let mappedGroupId = exportPerson.cadenceId
                    .flatMap { preview.groupIdMap[$0] }
                    .flatMap { validGroupIds.contains($0) ? $0 : nil }
                    ?? defaultGroupId

                let mappedTagIds = exportPerson.tagIds.compactMap { preview.tagIdMap[$0] ?? $0 }

                var person = Person(
                    id: newId,
                    cnIdentifier: nil,
                    displayName: exportPerson.displayName,
                    initials: InitialsBuilder.initials(for: exportPerson.displayName),
                    avatarColor: AvatarColors.randomHex(),
                    cadenceId: mappedGroupId,
                    tagIds: mappedTagIds,
                    lastTouchAt: exportPerson.lastTouchAt,
                    lastTouchMethod: nil,
                    lastTouchNotes: nil,
                    nextTouchNotes: nil,
                    isPaused: exportPerson.isPaused,
                    isTracked: true,
                    notificationsMuted: false,
                    customBreachTime: nil,
                    snoozedUntil: nil,
                    customDueDate: nil,
                    birthday: exportPerson.birthday.flatMap(Birthday.from(jsonString:)),
                    birthdayNotificationsEnabled: exportPerson.birthdayNotificationsEnabled ?? true,
                    contactUnavailable: false,
                    isDemoData: false,
                    cadenceAddedAt: nil,
                    createdAt: exportPerson.createdAt,
                    modifiedAt: now,
                    sortOrder: sortOrder
                )
                person = assignGroup.assign(person: person, to: mappedGroupId)
                personsToSave.append(person)
                importedNewPeople.append((id: newId, displayName: exportPerson.displayName))
                sortOrder += 1
            }

            // 5. Updated people — use remappedIds for CN/name-matched contacts
            // Include disambiguated people that the user resolved
            let allUpdatedPeople: [ExportPerson] = preview.updatedPeople + preview.ambiguousPeople
                .filter { preview.remappedIds[$0.export.id] != nil }
                .map(\.export)

            for exportPerson in allUpdatedPeople {
                let lookupId = preview.remappedIds[exportPerson.id] ?? exportPerson.id
                guard var person = existingById[lookupId] else { continue }
                importedIdMap[exportPerson.id] = person.id

                person.displayName = exportPerson.displayName
                person.initials = InitialsBuilder.initials(for: exportPerson.displayName)
                person.tagIds = exportPerson.tagIds.compactMap { preview.tagIdMap[$0] ?? $0 }
                person.lastTouchAt = exportPerson.lastTouchAt
                person.isPaused = exportPerson.isPaused
                person.birthday = exportPerson.birthday.flatMap(Birthday.from(jsonString:))
                if let birthdayNotifs = exportPerson.birthdayNotificationsEnabled {
                    person.birthdayNotificationsEnabled = birthdayNotifs
                }
                person.modifiedAt = now

                if let newGroupId = exportPerson.cadenceId
                    .flatMap({ preview.groupIdMap[$0] }),
                   validGroupIds.contains(newGroupId),
                   newGroupId != person.cadenceId {
                    person = assignGroup.assign(person: person, to: newGroupId)
                }
                personsToSave.append(person)
            }

            do {
                try peopleRepo.batchSave(personsToSave)
            } catch {
                AppLogger.logError(error, category: AppLogger.viewModel, context: "DataImportService.executeImport.people")
            }

            // 6. Touch events — fresh UUIDs, map personId to actual saved IDs
            let allExported = preview.newPeople + allUpdatedPeople
            // Track most recent event per person for denormalized field update
            var mostRecentEvent: [UUID: ExportTouchEvent] = [:]

            // Build content-based dedup set from existing touch events
            let calendar = Calendar.current
            var existingEventKeys: Set<String> = []
            for exportPerson in allExported {
                guard let actualPersonId = importedIdMap[exportPerson.id] else { continue }
                let existing = touchRepo.fetchAll(for: actualPersonId)
                for e in existing {
                    existingEventKeys.insert(DataImportService.touchEventDedupKey(personId: actualPersonId, date: e.at, method: e.method, notes: e.notes, calendar: calendar))
                }
            }

            var touchEventsToSave: [TouchEvent] = []
            for exportPerson in allExported {
                guard let events = exportPerson.touchEvents,
                      let actualPersonId = importedIdMap[exportPerson.id] else { continue }
                for event in events {
                    let method = TouchMethod(rawValue: event.method) ?? .other
                    let key = DataImportService.touchEventDedupKey(personId: actualPersonId, date: event.at, method: method, notes: event.notes, calendar: calendar)

                    guard !existingEventKeys.contains(key) else { continue }
                    existingEventKeys.insert(key)

                    touchEventsToSave.append(TouchEvent(
                        id: UUID(),
                        personId: actualPersonId,
                        at: event.at,
                        method: method,
                        notes: event.notes,
                        timeOfDay: nil,
                        createdAt: now,
                        modifiedAt: now
                    ))

                    // Track most recent event per person
                    if let current = mostRecentEvent[actualPersonId] {
                        if event.at > current.at { mostRecentEvent[actualPersonId] = event }
                    } else {
                        mostRecentEvent[actualPersonId] = event
                    }
                }
            }
            if !touchEventsToSave.isEmpty {
                do {
                    try touchRepo.batchSave(touchEventsToSave)
                } catch {
                    AppLogger.logError(error, category: AppLogger.viewModel, context: "DataImportService.executeImport.touchEvents")
                }
            }

            // 7. Update denormalized fields from imported touch events
            if !mostRecentEvent.isEmpty {
                var denormUpdates: [Person] = []
                for (personId, recentEvent) in mostRecentEvent {
                    guard var person = peopleRepo.fetch(id: personId) else { continue }
                    // Only update if imported event is more recent than stored
                    if person.lastTouchAt == nil || recentEvent.at > (person.lastTouchAt ?? .distantPast) {
                        person.lastTouchAt = recentEvent.at
                        person.lastTouchMethod = TouchMethod(rawValue: recentEvent.method)
                        person.lastTouchNotes = recentEvent.notes
                        person.modifiedAt = now
                        denormUpdates.append(person)
                    }
                }
                if !denormUpdates.isEmpty {
                    do {
                        try peopleRepo.batchSave(denormUpdates)
                    } catch {
                        AppLogger.logError(error, category: AppLogger.viewModel, context: "DataImportService.executeImport.denorm")
                    }
                }
            }
        }

        return ImportResult(
            importedPeople: importedNewPeople,
            totalPeople: preview.totalPeople,
            groupsCreated: preview.newGroups.count,
            tagsCreated: preview.newTags.count
        )
    }

    // MARK: - Post-Import Contact Matching

    func fetchContactMatches(people: [(id: UUID, displayName: String)]) async -> [ContactsFetcher.ContactMatchResult] {
        guard !people.isEmpty else { return [] }

        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized, .limited:
            break
        default:
            return []
        }

        return await Task.detached { () -> [ContactsFetcher.ContactMatchResult] in
            do {
                return try ContactsFetcher.matchByDisplayName(people: people)
            } catch {
                AppLogger.logError(error, category: AppLogger.contacts, context: "fetchContactMatches")
                return []
            }
        }.value
    }
}
