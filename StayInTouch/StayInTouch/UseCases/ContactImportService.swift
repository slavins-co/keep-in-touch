//
//  ContactImportService.swift
//  KeepInTouch
//
//  Handles importing contacts from the device's address book (CNContactStore).
//

import Foundation
import Contacts

struct ContactImportService {
    let personRepository: PersonRepository
    let touchEventRepository: TouchEventRepository
    let coreDataStack: CoreDataStack

    init(
        personRepository: PersonRepository,
        touchEventRepository: TouchEventRepository,
        coreDataStack: CoreDataStack = .shared
    ) {
        self.personRepository = personRepository
        self.touchEventRepository = touchEventRepository
        self.coreDataStack = coreDataStack
    }

    struct FetchResult {
        let contacts: [ContactSummary]
        let accessDenied: Bool
        let accessLimited: Bool
    }

    func fetchNewContacts() async -> FetchResult {
        let summaries = await Task.detached {
            do {
                return try ContactsFetcher.fetchAll()
            } catch {
                AppLogger.logError(error, category: AppLogger.viewModel, context: "ContactImportService.fetchNewContacts")
                return []
            }
        }.value

        if summaries.isEmpty {
            let status = CNContactStore.authorizationStatus(for: .contacts)
            let denied = (status == .denied || status == .restricted)
            let limited = Self.isLimitedAccess(status)
            return FetchResult(contacts: [], accessDenied: denied, accessLimited: limited)
        }

        let existing = Set(personRepository.fetchTracked(includePaused: true).compactMap { $0.cnIdentifier })
        let newContacts = summaries.filter { !existing.contains($0.identifier) }

        if newContacts.isEmpty {
            let status = CNContactStore.authorizationStatus(for: .contacts)
            let limited = Self.isLimitedAccess(status)
            return FetchResult(contacts: newContacts, accessDenied: false, accessLimited: limited)
        }

        return FetchResult(contacts: newContacts, accessDenied: false, accessLimited: false)
    }

    static func isLimitedAccess(_ status: CNAuthorizationStatus) -> Bool {
        if #available(iOS 18.0, *) {
            return status == .limited
        }
        return false
    }

    func importSelectedContacts(_ summaries: [ContactSummary], groupAssignments: [String: UUID] = [:], lastTouchSelections: [String: LastTouchOption] = [:]) async {
        guard !summaries.isEmpty else { return }

        let backgroundContext = coreDataStack.newBackgroundContext()
        await backgroundContext.perform {
            let peopleRepo = CoreDataPersonRepository(context: backgroundContext)
            let groupRepo = CoreDataCadenceRepository(context: backgroundContext)
            let touchRepo = CoreDataTouchEventRepository(context: backgroundContext)

            let groups = groupRepo.fetchAll()
            let defaultGroupId = groups.first(where: { $0.isDefault })?.id ?? groups.first?.id
            guard let defaultGroupId else { return }

            let existing = peopleRepo.fetchTracked(includePaused: true)
            var sortOrder = existing.count
            let now = Date()

            var personsToSave: [Person] = []
            var touchEventsToSave: [TouchEvent] = []

            for summary in summaries {
                let cadenceId = groupAssignments[summary.identifier] ?? defaultGroupId
                let lastTouchOption = lastTouchSelections[summary.identifier] ?? .cantRemember
                let seedDate = lastTouchOption.approximateDate(from: now)

                let personId = UUID()
                let person = Person(
                    id: personId,
                    cnIdentifier: summary.identifier,
                    displayName: summary.displayName,
                    initials: summary.initials,
                    avatarColor: AvatarColors.randomHex(),
                    cadenceId: cadenceId,
                    tagIds: [],
                    lastTouchAt: seedDate,
                    lastTouchMethod: seedDate != nil ? .other : nil,
                    lastTouchNotes: nil,
                    nextTouchNotes: nil,
                    isPaused: false,
                    isTracked: true,
                    notificationsMuted: false,
                    customBreachTime: nil,
                    snoozedUntil: nil,
                    customDueDate: nil,
                    birthday: nil,
                    birthdayNotificationsEnabled: true,
                    contactUnavailable: false,
                    isDemoData: false,
                    cadenceAddedAt: nil,
                    createdAt: now,
                    modifiedAt: now,
                    sortOrder: sortOrder
                )

                personsToSave.append(AssignCadenceUseCase(referenceDate: now).assign(person: person, to: cadenceId))

                if let seedDate {
                    touchEventsToSave.append(TouchEvent(
                        id: UUID(),
                        personId: personId,
                        at: seedDate,
                        method: .other,
                        notes: nil,
                        timeOfDay: nil,
                        createdAt: now,
                        modifiedAt: now
                    ))
                }

                sortOrder += 1
            }

            do {
                if !touchEventsToSave.isEmpty {
                    try touchRepo.batchSave(touchEventsToSave)
                }
                try peopleRepo.batchSave(personsToSave)
            } catch {
                AppLogger.logError(error, category: AppLogger.viewModel, context: "ContactImportService.importSelectedContacts")
            }
        }
    }
}
