//
//  SettingsViewModel.swift
//  StayInTouch
//
//  Created by Codex on 2/3/26.
//

import Foundation
import UserNotifications
import Contacts

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var settings: AppSettings
    @Published private(set) var allGroups: [Group] = []
    @Published private(set) var groupsCount: Int = 0
    @Published private(set) var tagsCount: Int = 0
    @Published private(set) var pausedCount: Int = 0
    @Published var showNotificationsSettingsAlert = false
    @Published var pendingNewContacts: [ContactSummary] = []
    @Published var contactAccessDenied = false
    @Published var contactAccessLimited = false

    private let settingsRepository: AppSettingsRepository
    private let groupRepository: GroupRepository
    private let tagRepository: TagRepository
    private let personRepository: PersonRepository
    private let touchEventRepository: TouchEventRepository

    init(
        settingsRepository: AppSettingsRepository = CoreDataAppSettingsRepository(context: CoreDataStack.shared.viewContext),
        groupRepository: GroupRepository = CoreDataGroupRepository(context: CoreDataStack.shared.viewContext),
        tagRepository: TagRepository = CoreDataTagRepository(context: CoreDataStack.shared.viewContext),
        personRepository: PersonRepository = CoreDataPersonRepository(context: CoreDataStack.shared.viewContext),
        touchEventRepository: TouchEventRepository = CoreDataTouchEventRepository(context: CoreDataStack.shared.viewContext)
    ) {
        self.settingsRepository = settingsRepository
        self.groupRepository = groupRepository
        self.tagRepository = tagRepository
        self.personRepository = personRepository
        self.touchEventRepository = touchEventRepository
        self.settings = settingsRepository.fetch() ?? AppSettingsDefaults.defaultSettings()
        load()
    }

    func load() {
        settings = settingsRepository.fetch() ?? AppSettingsDefaults.defaultSettings()
        allGroups = groupRepository.fetchAll()
        groupsCount = allGroups.count
        tagsCount = tagRepository.fetchAll().count
        pausedCount = personRepository.fetchTracked(includePaused: true).filter { $0.isPaused }.count
    }

    func setTheme(_ theme: Theme) {
        AnalyticsService.track("settings.theme.changed", parameters: ["theme": theme.rawValue])
        settings.theme = theme
        save()
    }

    func setNotificationsEnabled(_ enabled: Bool) async {
        AnalyticsService.track("settings.notifications.toggled", parameters: ["enabled": String(enabled)])
        if enabled {
            let granted = await requestNotificationsPermission()
            if granted {
                settings.notificationsEnabled = true
                save()
            } else {
                settings.notificationsEnabled = false
                save()
                showNotificationsSettingsAlert = true
            }
        } else {
            settings.notificationsEnabled = false
            save()
        }
    }

    func setBreachTime(_ time: LocalTime) {
        settings.breachTimeOfDay = time
        save()
    }

    func setDigestEnabled(_ enabled: Bool) {
        settings.digestEnabled = enabled
        save()
    }

    func setDigestDay(_ day: DayOfWeek) {
        settings.digestDay = day
        save()
    }

    func setDigestTime(_ time: LocalTime) {
        settings.digestTime = time
        save()
    }

    func setNotificationGrouping(_ grouping: NotificationGrouping) {
        settings.notificationGrouping = grouping
        save()
    }

    func setBadgeCountShowDueSoon(_ enabled: Bool) {
        settings.badgeCountShowDueSoon = enabled
        save()
    }

    func setAnalyticsEnabled(_ enabled: Bool) {
        settings.analyticsEnabled = enabled
        save()
        AnalyticsService.updateEnabled(enabled)
        AnalyticsService.track("settings.analytics.toggled", parameters: ["enabled": String(enabled)])
    }

    func setDemoModeEnabled(_ enabled: Bool) {
        settings.demoModeEnabled = enabled
        save()
        Task { await updateDemoData(enabled) }
    }

    private func updateDemoData(_ enabled: Bool) async {
        let backgroundContext = CoreDataStack.shared.newBackgroundContext()
        await backgroundContext.perform {
            if enabled {
                let seeder = DemoDataSeeder(context: backgroundContext)
                seeder.seedIfNeeded()
            } else {
                let repo = CoreDataPersonRepository(context: backgroundContext)
                let touchRepo = CoreDataTouchEventRepository(context: backgroundContext)
                let demoPeople = repo.fetchAll().filter { $0.isDemoData }
                for person in demoPeople {
                    do {
                        // Cascade: delete TouchEvents before Person
                        let events = touchRepo.fetchAll(for: person.id)
                        for event in events {
                            try touchRepo.delete(id: event.id)
                        }
                        try repo.delete(id: person.id)
                    } catch {
                        AppLogger.logError(error, category: AppLogger.viewModel, context: "SettingsViewModel.updateDemoData")
                    }
                }
            }
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .personDidChange, object: nil)
        }
    }

    func sendTestNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "Stay in Touch test notification."
        content.sound = .default
        content.userInfo = ["type": "home", "category": "test"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(identifier: "test_notification", content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "SettingsViewModel.sendTestNotification")
        }
    }

    func resetAllFrequencies() async {
        let now = Date()
        let backgroundContext = CoreDataStack.shared.newBackgroundContext()
        await backgroundContext.perform {
            let repo = CoreDataPersonRepository(context: backgroundContext)
            let people = repo.fetchTracked(includePaused: true)
            var updated: [Person] = []
            for var person in people {
                person.lastTouchAt = now
                person.modifiedAt = now
                updated.append(person)
            }
            do {
                try repo.batchSave(updated)
            } catch {
                AppLogger.logError(error, category: AppLogger.viewModel, context: "SettingsViewModel.resetAllFrequencies")
            }
        }
        await MainActor.run {
            load()
            NotificationCenter.default.post(name: .personDidChange, object: nil)
        }
    }

    func exportContacts() -> URL? {
        let people = personRepository.fetchAll()
        let groups = groupRepository.fetchAll()
        let tags = tagRepository.fetchAll()

        let groupNameById = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0.name) })
        let tagNameById = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0.name) })

        let exportPeople = people.map { person in
            ExportPerson.from(
                person,
                groupName: groupNameById[person.groupId],
                tagNames: person.tagIds.compactMap { tagNameById[$0] },
                touchEvents: touchEventRepository.fetchAll(for: person.id)
            )
        }

        let exportData = ExportData(
            version: 2,
            exportedAt: Date(),
            groups: groups.map { ExportGroup.from($0) },
            tags: tags.map { ExportTag.from($0) },
            people: exportPeople
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(exportData) else { return nil }

        let filename = "stayintouch-export-\(ISO8601DateFormatter().string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    func parseImportFile(url: URL) -> ImportPreview? {
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Try new format first, fall back to legacy [ExportPerson] array
        let importedPeople: [ExportPerson]
        let importedGroups: [ExportGroup]
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

        // --- Group merge: match by normalized name, skip duplicates ---
        let existingGroups = groupRepository.fetchAll()
        let existingGroupsByName = Dictionary(
            grouping: existingGroups,
            by: { $0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        )
        var groupIdMap: [UUID: UUID] = [:]
        var newGroups: [ExportGroup] = []

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
        // Only match by internal UUID — never trust cnIdentifier from external files
        let existingById = Dictionary(uniqueKeysWithValues: personRepository.fetchAll().map { ($0.id, $0) })

        var newPeople: [ExportPerson] = []
        var updatedPeople: [ExportPerson] = []
        var skipped = 0
        var touchEventCount = 0

        for person in importedPeople {
            guard !person.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                skipped += 1
                continue
            }

            if existingById[person.id] != nil {
                updatedPeople.append(person)
            } else {
                newPeople.append(person)
            }
            touchEventCount += person.touchEvents?.count ?? 0
        }

        return ImportPreview(
            newPeople: newPeople,
            updatedPeople: updatedPeople,
            skippedCount: skipped,
            touchEventCount: touchEventCount,
            newGroups: newGroups,
            newTags: newTags,
            groupIdMap: groupIdMap,
            tagIdMap: tagIdMap
        )
    }

    func executeImport(_ preview: ImportPreview) async -> ImportResult {
        var importedNewPeople: [(id: UUID, displayName: String)] = []

        let backgroundContext = CoreDataStack.shared.newBackgroundContext()
        await backgroundContext.perform {
            let peopleRepo = CoreDataPersonRepository(context: backgroundContext)
            let touchRepo = CoreDataTouchEventRepository(context: backgroundContext)
            let groupRepo = CoreDataGroupRepository(context: backgroundContext)
            let tagRepo = CoreDataTagRepository(context: backgroundContext)

            let now = Date()

            // 1. Create new groups from import
            let existingGroupCount = groupRepo.fetchAll().count
            for (index, exportGroup) in preview.newGroups.enumerated() {
                guard let newId = preview.groupIdMap[exportGroup.id] else { continue }
                let group = Group(
                    id: newId,
                    name: exportGroup.name,
                    frequencyDays: exportGroup.frequencyDays,
                    warningDays: exportGroup.warningDays,
                    colorHex: exportGroup.colorHex,
                    isDefault: false,
                    sortOrder: existingGroupCount + index,
                    createdAt: now,
                    modifiedAt: now
                )
                do {
                    try groupRepo.save(group)
                } catch {
                    AppLogger.logError(error, category: AppLogger.viewModel, context: "SettingsViewModel.executeImport.groups")
                }
            }

            // 2. Create new tags from import
            let existingTagCount = tagRepo.fetchAll().count
            for (index, exportTag) in preview.newTags.enumerated() {
                guard let newId = preview.tagIdMap[exportTag.id] else { continue }
                let tag = Tag(
                    id: newId,
                    name: exportTag.name,
                    colorHex: exportTag.colorHex,
                    sortOrder: existingTagCount + index,
                    createdAt: now,
                    modifiedAt: now
                )
                do {
                    try tagRepo.save(tag)
                } catch {
                    AppLogger.logError(error, category: AppLogger.viewModel, context: "SettingsViewModel.executeImport.tags")
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
            let assignGroup = AssignGroupUseCase(referenceDate: now)

            var personsToSave: [Person] = []
            var importedIdMap: [UUID: UUID] = [:]

            // 4. New people — remap groupId and tagIds
            for exportPerson in preview.newPeople {
                let newId = UUID()
                importedIdMap[exportPerson.id] = newId

                let mappedGroupId = exportPerson.groupId
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
                    groupId: mappedGroupId,
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
                    birthday: exportPerson.birthday.flatMap(Birthday.from(jsonString:)),
                    contactUnavailable: false,
                    isDemoData: false,
                    groupAddedAt: nil,
                    createdAt: exportPerson.createdAt,
                    modifiedAt: now,
                    sortOrder: sortOrder
                )
                person = assignGroup.assign(person: person, to: mappedGroupId)
                personsToSave.append(person)
                importedNewPeople.append((id: newId, displayName: exportPerson.displayName))
                sortOrder += 1
            }

            // 5. Updated people — remap groupId and tagIds
            for exportPerson in preview.updatedPeople {
                guard var person = existingById[exportPerson.id] else { continue }
                importedIdMap[exportPerson.id] = person.id

                person.displayName = exportPerson.displayName
                person.initials = InitialsBuilder.initials(for: exportPerson.displayName)
                person.tagIds = exportPerson.tagIds.compactMap { preview.tagIdMap[$0] ?? $0 }
                person.lastTouchAt = exportPerson.lastTouchAt
                person.isPaused = exportPerson.isPaused
                person.birthday = exportPerson.birthday.flatMap(Birthday.from(jsonString:))
                person.modifiedAt = now

                if let newGroupId = exportPerson.groupId
                    .flatMap({ preview.groupIdMap[$0] }),
                   validGroupIds.contains(newGroupId),
                   newGroupId != person.groupId {
                    person = assignGroup.assign(person: person, to: newGroupId)
                }
                personsToSave.append(person)
            }

            do {
                try peopleRepo.batchSave(personsToSave)
            } catch {
                AppLogger.logError(error, category: AppLogger.viewModel, context: "SettingsViewModel.executeImport.people")
            }

            // 6. Touch events — fresh UUIDs, map personId to actual saved IDs
            let allExported = preview.newPeople + preview.updatedPeople
            for exportPerson in allExported {
                guard let events = exportPerson.touchEvents,
                      let actualPersonId = importedIdMap[exportPerson.id] else { continue }
                for event in events {
                    let method = TouchMethod(rawValue: event.method) ?? .other
                    let touchEvent = TouchEvent(
                        id: UUID(),
                        personId: actualPersonId,
                        at: event.at,
                        method: method,
                        notes: event.notes,
                        timeOfDay: nil,
                        createdAt: now,
                        modifiedAt: now
                    )
                    do {
                        try touchRepo.save(touchEvent)
                    } catch {
                        AppLogger.logError(error, category: AppLogger.viewModel, context: "SettingsViewModel.executeImport.touchEvents")
                    }
                }
            }
        }

        load()
        NotificationCenter.default.post(name: .personDidChange, object: nil)

        return ImportResult(
            importedPeople: importedNewPeople,
            totalPeople: preview.totalPeople,
            groupsCreated: preview.newGroups.count,
            tagsCreated: preview.newTags.count
        )
    }

    // MARK: - Post-Import Contact Matching

    func matchImportedContacts(people: [(id: UUID, displayName: String)]) async -> ContactMatchSummary {
        guard !people.isEmpty else {
            return ContactMatchSummary(matched: 0, unmatchedPeople: [], total: 0, matchedNames: [])
        }

        let status = CNContactStore.authorizationStatus(for: .contacts)
        let isAuthorized: Bool
        if #available(iOS 18.0, *) {
            isAuthorized = status == .authorized || status == .limited
        } else {
            isAuthorized = status == .authorized
        }
        guard isAuthorized else {
            return ContactMatchSummary(
                matched: 0,
                unmatchedPeople: people,
                total: people.count,
                matchedNames: []
            )
        }

        let results = await Task.detached { () -> [ContactsFetcher.ContactMatchResult] in
            do {
                return try ContactsFetcher.matchByDisplayName(people: people)
            } catch {
                AppLogger.logError(error, category: AppLogger.contacts, context: "matchImportedContacts")
                return []
            }
        }.value

        guard !results.isEmpty else {
            return ContactMatchSummary(matched: 0, unmatchedPeople: people, total: people.count, matchedNames: [])
        }

        var matchedCount = 0
        var matchedNames: [String] = []
        var unmatchedPeople: [(id: UUID, displayName: String)] = []

        for result in results {
            switch result {
            case .matched(let personId, let displayName, let cnIdentifier):
                if var person = personRepository.fetch(id: personId) {
                    person.cnIdentifier = cnIdentifier
                    person.contactUnavailable = false
                    person.modifiedAt = Date()
                    do {
                        try personRepository.save(person)
                        matchedCount += 1
                        matchedNames.append(displayName)
                    } catch {
                        AppLogger.logError(error, category: AppLogger.viewModel, context: "matchImportedContacts.save")
                        unmatchedPeople.append((id: personId, displayName: displayName))
                    }
                } else {
                    unmatchedPeople.append((id: personId, displayName: displayName))
                }
            case .multipleMatches(let personId, let displayName, _):
                unmatchedPeople.append((id: personId, displayName: displayName))
            case .noMatch(let personId, let displayName):
                unmatchedPeople.append((id: personId, displayName: displayName))
            }
        }

        if matchedCount > 0 {
            load()
            NotificationCenter.default.post(name: .personDidChange, object: nil)
        }

        return ContactMatchSummary(
            matched: matchedCount,
            unmatchedPeople: unmatchedPeople,
            total: people.count,
            matchedNames: matchedNames
        )
    }

    func linkContactManually(personId: UUID, cnIdentifier: String) {
        guard var person = personRepository.fetch(id: personId) else { return }
        person.cnIdentifier = cnIdentifier
        person.contactUnavailable = false
        person.modifiedAt = Date()
        do {
            try personRepository.save(person)
            load()
            NotificationCenter.default.post(name: .personDidChange, object: nil)
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "linkContactManually")
        }
    }

    func findNewContacts() async -> Int {
        contactAccessDenied = false
        contactAccessLimited = false
        let summaries = await Task.detached {
            do {
                return try ContactsFetcher.fetchAll()
            } catch {
                AppLogger.logError(error, category: AppLogger.viewModel, context: "SettingsViewModel.findNewContacts")
                return []
            }
        }.value
        guard !summaries.isEmpty else {
            let status = CNContactStore.authorizationStatus(for: .contacts)
            contactAccessDenied = (status == .denied || status == .restricted)
            contactAccessLimited = Self.isLimitedAccess(status)
            return 0
        }

        let existing = Set(personRepository.fetchTracked(includePaused: true).compactMap { $0.cnIdentifier })
        let newContacts = summaries.filter { !existing.contains($0.identifier) }
        if newContacts.isEmpty {
            let status = CNContactStore.authorizationStatus(for: .contacts)
            contactAccessLimited = Self.isLimitedAccess(status)
        }
        pendingNewContacts = newContacts
        return newContacts.count
    }

    private static func isLimitedAccess(_ status: CNAuthorizationStatus) -> Bool {
        if #available(iOS 18.0, *) {
            return status == .limited
        }
        return false
    }

    func importSelectedContacts(_ summaries: [ContactSummary]) async {
        await importSelectedContacts(summaries, groupAssignments: [:])
    }

    func importSelectedContacts(_ summaries: [ContactSummary], groupAssignments: [String: UUID]) async {
        guard !summaries.isEmpty else { return }

        let backgroundContext = CoreDataStack.shared.newBackgroundContext()
        await backgroundContext.perform {
            let peopleRepo = CoreDataPersonRepository(context: backgroundContext)
            let groupRepo = CoreDataGroupRepository(context: backgroundContext)

            let groups = groupRepo.fetchAll()
            let defaultGroupId = groups.first(where: { $0.isDefault })?.id ?? groups.first?.id
            guard let defaultGroupId else { return }

            let existing = peopleRepo.fetchTracked(includePaused: true)
            var sortOrder = existing.count
            let now = Date()

            var personsToSave: [Person] = []

            for summary in summaries {
                let groupId = groupAssignments[summary.identifier] ?? defaultGroupId
                let person = Person(
                    id: UUID(),
                    cnIdentifier: summary.identifier,
                    displayName: summary.displayName,
                    initials: summary.initials,
                    avatarColor: AvatarColors.randomHex(),
                    groupId: groupId,
                    tagIds: [],
                    lastTouchAt: nil,
                    lastTouchMethod: nil,
                    lastTouchNotes: nil,
                    nextTouchNotes: nil,
                    isPaused: false,
                    isTracked: true,
                    notificationsMuted: false,
                    customBreachTime: nil,
                    snoozedUntil: nil,
                    birthday: nil,
                    contactUnavailable: false,
                    isDemoData: false,
                    groupAddedAt: nil,
                    createdAt: now,
                    modifiedAt: now,
                    sortOrder: sortOrder
                )

                personsToSave.append(AssignGroupUseCase(referenceDate: now).assign(person: person, to: groupId))
                sortOrder += 1
            }

            do {
                try peopleRepo.batchSave(personsToSave)
            } catch {
                AppLogger.logError(error, category: AppLogger.viewModel, context: "SettingsViewModel.importSelectedContacts")
            }
        }

        pendingNewContacts = pendingNewContacts.filter { existing in
            !summaries.contains(where: { $0.identifier == existing.identifier })
        }

        settings.lastContactsSyncAt = Date()
        save()
        load()
        NotificationCenter.default.post(name: .contactsDidSync, object: nil)
    }

    private func save() {
        do {
            try settingsRepository.save(settings)
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "SettingsViewModel.save")
            ErrorToastManager.shared.show(.saveFailed("Settings"))
        }
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }

    private func requestNotificationsPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .badge, .sound])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }
}

struct ExportGroup: Codable {
    let id: UUID
    let name: String
    let frequencyDays: Int
    let warningDays: Int
    let colorHex: String?
    let sortOrder: Int
    let isDefault: Bool

    static func from(_ group: Group) -> ExportGroup {
        ExportGroup(
            id: group.id,
            name: group.name,
            frequencyDays: group.frequencyDays,
            warningDays: group.warningDays,
            colorHex: group.colorHex,
            sortOrder: group.sortOrder,
            isDefault: group.isDefault
        )
    }
}

struct ExportTag: Codable {
    let id: UUID
    let name: String
    let colorHex: String
    let sortOrder: Int

    static func from(_ tag: Tag) -> ExportTag {
        ExportTag(
            id: tag.id,
            name: tag.name,
            colorHex: tag.colorHex,
            sortOrder: tag.sortOrder
        )
    }
}

struct ExportData: Codable {
    let version: Int
    let exportedAt: Date
    let groups: [ExportGroup]
    let tags: [ExportTag]
    let people: [ExportPerson]
}

struct ExportTouchEvent: Codable {
    let id: UUID
    let at: Date
    let method: String
    let notes: String?

    static func from(_ event: TouchEvent) -> ExportTouchEvent {
        ExportTouchEvent(
            id: event.id,
            at: event.at,
            method: event.method.rawValue,
            notes: event.notes
        )
    }
}

struct ExportPerson: Codable {
    let id: UUID
    let displayName: String
    let groupId: UUID?
    let groupName: String?
    let tagIds: [UUID]
    let tagNames: [String]
    let lastTouchAt: Date?
    let isPaused: Bool
    let createdAt: Date
    let modifiedAt: Date
    let touchEvents: [ExportTouchEvent]?
    let birthday: String?

    static func from(_ person: Person, groupName: String?, tagNames: [String], touchEvents: [TouchEvent]) -> ExportPerson {
        let exportEvents: [ExportTouchEvent]? = touchEvents.isEmpty ? nil : touchEvents.map { ExportTouchEvent.from($0) }
        return ExportPerson(
            id: person.id,
            displayName: person.displayName,
            groupId: person.groupId,
            groupName: groupName,
            tagIds: person.tagIds,
            tagNames: tagNames,
            lastTouchAt: person.lastTouchAt,
            isPaused: person.isPaused,
            createdAt: person.createdAt,
            modifiedAt: person.modifiedAt,
            touchEvents: exportEvents,
            birthday: person.birthday?.toJsonString()
        )
    }
}

struct ImportPreview {
    let newPeople: [ExportPerson]
    let updatedPeople: [ExportPerson]
    let skippedCount: Int
    let touchEventCount: Int
    let newGroups: [ExportGroup]
    let newTags: [ExportTag]
    let groupIdMap: [UUID: UUID]
    let tagIdMap: [UUID: UUID]

    var totalPeople: Int { newPeople.count + updatedPeople.count }
    var isEmpty: Bool { newPeople.isEmpty && updatedPeople.isEmpty && newGroups.isEmpty && newTags.isEmpty }
}

struct ImportResult {
    let importedPeople: [(id: UUID, displayName: String)]
    let totalPeople: Int
    let groupsCreated: Int
    let tagsCreated: Int
}

struct ContactMatchSummary {
    let matched: Int
    let unmatchedPeople: [(id: UUID, displayName: String)]
    let total: Int
    let matchedNames: [String]
}

struct AppSettingsDefaults {
    static func defaultSettings() -> AppSettings {
        AppSettings(
            id: AppSettings.singletonId,
            theme: .system,
            notificationsEnabled: false,
            breachTimeOfDay: LocalTime(hour: 18, minute: 0),
            digestEnabled: false,
            digestDay: .friday,
            digestTime: LocalTime(hour: 18, minute: 0),
            notificationGrouping: .perType,
            badgeCountShowDueSoon: false,
            dueSoonWindowDays: 3,
            demoModeEnabled: false,
            analyticsEnabled: true,
            lastContactsSyncAt: nil,
            onboardingCompleted: false,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        )
    }
}
