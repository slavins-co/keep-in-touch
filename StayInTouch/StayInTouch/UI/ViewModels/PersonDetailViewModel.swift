//
//  PersonDetailViewModel.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

@MainActor
final class PersonDetailViewModel: ObservableObject {
    @Published private(set) var person: Person
    @Published private(set) var group: Group?
    @Published private(set) var groups: [Group] = []
    @Published private(set) var tags: [Tag] = []
    @Published private(set) var availableTags: [Tag] = []
    @Published private(set) var touchEvents: [TouchEvent] = []
    @Published private(set) var phone: String?
    @Published private(set) var email: String?
    @Published private(set) var phoneNumbers: [ContactsFetcher.LabeledValue] = []
    @Published private(set) var emailAddresses: [ContactsFetcher.LabeledValue] = []
    @Published var contactBirthday: Birthday?
    @Published var quickActionMessage: String?
    @Published var showPhonePicker = false
    @Published var showEmailPicker = false
    var pendingPhoneAction: QuickActionType?

    private let personRepository: PersonRepository
    private let groupRepository: GroupRepository
    private let tagRepository: TagRepository
    private let touchRepository: TouchEventRepository

    init(
        person: Person,
        personRepository: PersonRepository = CoreDataPersonRepository(context: CoreDataStack.shared.viewContext),
        groupRepository: GroupRepository = CoreDataGroupRepository(context: CoreDataStack.shared.viewContext),
        tagRepository: TagRepository = CoreDataTagRepository(context: CoreDataStack.shared.viewContext),
        touchRepository: TouchEventRepository = CoreDataTouchEventRepository(context: CoreDataStack.shared.viewContext)
    ) {
        self.person = person
        self.personRepository = personRepository
        self.groupRepository = groupRepository
        self.tagRepository = tagRepository
        self.touchRepository = touchRepository
        load()
        AnalyticsService.track("person.viewed")
    }

    convenience init(person: Person, dependencies: AppDependencies) {
        self.init(
            person: person,
            personRepository: dependencies.personRepository,
            groupRepository: dependencies.groupRepository,
            tagRepository: dependencies.tagRepository,
            touchRepository: dependencies.touchEventRepository
        )
    }

    func load() {
        if let refreshed = personRepository.fetch(id: person.id) {
            person = refreshed
        }
        groups = groupRepository.fetchAll()
        group = groupRepository.fetch(id: person.groupId)
        tags = tagRepository.fetchAll()
        availableTags = tags.filter { !person.tagIds.contains($0.id) }
        touchEvents = fetchSortedEvents()
    }

    func refreshContactInfo() async {
        guard let cnId = person.cnIdentifier else {
            phone = nil
            email = nil
            phoneNumbers = []
            emailAddresses = []
            contactBirthday = nil
            return
        }

        let fetchResult = await Task.detached(priority: .userInitiated) { () -> Result<ContactsFetcher.ContactInfo, Error> in
            do {
                let info = try ContactsFetcher.fetchContactInfo(identifier: cnId)
                return .success(info)
            } catch {
                return .failure(error)
            }
        }.value

        switch fetchResult {
        case .success(let info):
            phone = info.phone
            email = info.email
            phoneNumbers = info.phoneNumbers
            emailAddresses = info.emailAddresses
            contactBirthday = info.birthday.flatMap(Birthday.from(dateComponents:))
            if person.contactUnavailable {
                var updated = person
                updated.contactUnavailable = false
                updated.modifiedAt = Date()
                savePerson(updated)
            }
        case .failure(let error):
            phone = nil
            email = nil
            phoneNumbers = []
            emailAddresses = []
            contactBirthday = nil
            if case ContactsFetcherError.contactNotFound = error {
                if !person.contactUnavailable {
                    var updated = person
                    updated.contactUnavailable = true
                    updated.modifiedAt = Date()
                    savePerson(updated)
                }
            } else {
                AppLogger.logError(error, category: AppLogger.viewModel, context: "PersonDetailViewModel.refreshContactInfo")
            }
        }
    }

    /// Returns the birthday to display: manual override takes precedence over CNContact birthday
    var displayBirthday: Birthday? {
        person.birthday ?? contactBirthday
    }

    func setBirthday(_ birthday: Birthday?) {
        var updated = person
        updated.birthday = birthday
        updated.modifiedAt = Date()
        savePerson(updated)
    }

    func setBirthdayNotificationsEnabled(_ enabled: Bool) {
        AnalyticsService.track("person.birthdayNotifications.toggled", parameters: ["enabled": String(enabled)])
        var updated = person
        updated.birthdayNotificationsEnabled = enabled
        updated.modifiedAt = Date()
        savePerson(updated)
    }

    func changeGroup(to groupId: UUID) {
        let updated = AssignGroupUseCase().assign(person: person, to: groupId)
        savePerson(updated)
        group = groupRepository.fetch(id: groupId)
    }

    func togglePause() {
        var updated = person
        updated.isPaused.toggle()
        updated.modifiedAt = Date()
        AnalyticsService.track(updated.isPaused ? "person.paused" : "person.resumed")
        savePerson(updated)
    }

    func setNotificationsMuted(_ muted: Bool) {
        var updated = person
        updated.notificationsMuted = muted
        updated.modifiedAt = Date()
        savePerson(updated)
    }

    func setCustomBreachTime(_ time: LocalTime?) {
        var updated = person
        updated.customBreachTime = time
        updated.modifiedAt = Date()
        savePerson(updated)
    }

    func saveNextTouchNotes(_ notes: String?) {
        var updated = person
        updated.nextTouchNotes = notes?.isEmpty == true ? nil : notes
        updated.modifiedAt = Date()
        savePerson(updated)
    }

    func snooze(until date: Date) {
        AnalyticsService.track("person.snoozed")
        var updated = person
        updated.snoozedUntil = date
        updated.modifiedAt = Date()
        savePerson(updated)
    }

    func clearSnooze() {
        var updated = person
        updated.snoozedUntil = nil
        updated.modifiedAt = Date()
        savePerson(updated)
    }

    func setCustomDueDate(_ date: Date?) {
        AnalyticsService.track(date != nil ? "person.customDueDate.set" : "person.customDueDate.cleared")
        var updated = person
        updated.customDueDate = date
        updated.modifiedAt = Date()
        savePerson(updated)
    }

    func clearCustomDueDate() {
        setCustomDueDate(nil)
    }

    func restoreNotificationDefaults() {
        var updated = person
        updated.customBreachTime = nil
        updated.notificationsMuted = false
        updated.modifiedAt = Date()
        savePerson(updated)
    }

    func resumeAndUpdateLastTouch(date: Date?) {
        var updated = person
        updated.isPaused = false
        updated.modifiedAt = Date()

        if let date {
            let touch = TouchEvent(
                id: UUID(),
                personId: person.id,
                at: date,
                method: .other,
                notes: "Resumed tracking",
                timeOfDay: nil,
                createdAt: Date(),
                modifiedAt: Date()
            )
            do {
                try touchRepository.save(touch)
            } catch let error as RepositoryError {
                AppLogger.logError(error, category: AppLogger.viewModel, context: "PersonDetailViewModel.resumeAndUpdateLastTouch")
                ErrorToastManager.shared.show(AppError(message: error.userMessage))
            } catch {
                AppLogger.logError(error, category: AppLogger.viewModel, context: "PersonDetailViewModel.resumeAndUpdateLastTouch (unexpected)")
                ErrorToastManager.shared.show(.saveFailed("PersonDetail"))
            }

            updated.lastTouchAt = date
            updated.lastTouchMethod = .other
            updated.lastTouchNotes = "Resumed tracking"
        }

        savePerson(updated)
        touchEvents = fetchSortedEvents()
    }

    func addTag(_ tag: Tag) {
        guard !person.tagIds.contains(tag.id) else { return }
        var updated = person
        updated.tagIds.append(tag.id)
        updated.modifiedAt = Date()
        savePerson(updated)
        availableTags = tags.filter { !updated.tagIds.contains($0.id) }
    }

    func removeTag(_ tag: Tag) {
        var updated = person
        updated.tagIds.removeAll { $0 == tag.id }
        updated.modifiedAt = Date()
        savePerson(updated)
        availableTags = tags.filter { !updated.tagIds.contains($0.id) }
    }

    func logTouch(method: TouchMethod, notes: String?, date: Date, timeOfDay: TimeOfDay? = nil) {
        AnalyticsService.track("connection.logged", parameters: ["method": method.rawValue])
        let now = date
        let touch = TouchEvent(
            id: UUID(),
            personId: person.id,
            at: now,
            method: method,
            notes: notes,
            timeOfDay: timeOfDay,
            createdAt: now,
            modifiedAt: now
        )
        do {
            try touchRepository.save(touch)
        } catch let error as RepositoryError {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "PersonDetailViewModel.logTouch")
            ErrorToastManager.shared.show(AppError(message: error.userMessage))
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "PersonDetailViewModel.logTouch (unexpected)")
            ErrorToastManager.shared.show(.saveFailed("PersonDetail"))
        }

        var updated = person
        updated.lastTouchAt = now
        updated.lastTouchMethod = method
        updated.lastTouchNotes = notes
        updated.snoozedUntil = nil
        updated.customDueDate = nil
        updated.modifiedAt = now
        savePerson(updated)

        touchEvents = fetchSortedEvents()
    }

    func updateTouch(_ touch: TouchEvent, method: TouchMethod, notes: String?, timeOfDay: TimeOfDay? = nil) {
        var updatedTouch = touch
        updatedTouch.method = method
        updatedTouch.timeOfDay = timeOfDay
        updatedTouch.notes = notes
        updatedTouch.modifiedAt = Date()
        do {
            try touchRepository.save(updatedTouch)
        } catch let error as RepositoryError {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "PersonDetailViewModel.updateTouch")
            ErrorToastManager.shared.show(AppError(message: error.userMessage))
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "PersonDetailViewModel.updateTouch (unexpected)")
            ErrorToastManager.shared.show(.saveFailed("PersonDetail"))
        }

        touchEvents = fetchSortedEvents()

        if touchEvents.first?.id == updatedTouch.id {
            var updated = person
            updated.lastTouchMethod = method
            updated.lastTouchNotes = notes
            updated.modifiedAt = Date()
            savePerson(updated)
        }
    }

    func deleteTouch(_ touch: TouchEvent) {
        AnalyticsService.track("connection.deleted")
        do {
            try touchRepository.delete(id: touch.id)
        } catch let error as RepositoryError {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "PersonDetailViewModel.deleteTouch")
            ErrorToastManager.shared.show(AppError(message: error.userMessage))
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "PersonDetailViewModel.deleteTouch (unexpected)")
            ErrorToastManager.shared.show(.deleteFailed("PersonDetail"))
        }
        touchEvents = fetchSortedEvents()

        var updated = person
        if let latest = touchEvents.first {
            updated.lastTouchAt = latest.at
            updated.lastTouchMethod = latest.method
            updated.lastTouchNotes = latest.notes
        } else {
            updated.lastTouchAt = nil
            updated.lastTouchMethod = nil
            updated.lastTouchNotes = nil
        }
        updated.modifiedAt = Date()
        savePerson(updated)
    }

    func relinkContact(cnIdentifier: String) {
        AnalyticsService.track("person.contactRelinked")
        var updated = person
        updated.cnIdentifier = cnIdentifier
        updated.modifiedAt = Date()
        savePerson(updated)
        Task { await refreshContactInfo() }
    }

    func deletePerson() {
        AnalyticsService.track("person.deleted")
        do {
            // Cascade: delete all TouchEvents for this person first
            let events = touchRepository.fetchAll(for: person.id)
            for event in events {
                try touchRepository.delete(id: event.id)
            }
            try personRepository.delete(id: person.id)
            NotificationCenter.default.post(name: .personDidChange, object: person.id)
        } catch let error as RepositoryError {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "PersonDetailViewModel.deletePerson")
            ErrorToastManager.shared.show(AppError(message: error.userMessage))
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "PersonDetailViewModel.deletePerson (unexpected)")
            ErrorToastManager.shared.show(.deleteFailed("PersonDetail"))
        }
    }

    func openAction(type: QuickActionType) -> URL? {
        quickActionMessage = nil
        switch type {
        case .message, .call:
            if phoneNumbers.count > 1 {
                pendingPhoneAction = type
                showPhonePicker = true
                return nil
            }
            guard let phone else {
                quickActionMessage = "Whoops — no phone number found."
                return nil
            }
            return buildPhoneURL(type: type, phone: phone)
        case .email:
            if emailAddresses.count > 1 {
                showEmailPicker = true
                return nil
            }
            guard let email else {
                quickActionMessage = "Whoops — no email address found."
                return nil
            }
            return buildEmailURL(email: email)
        }
    }

    func openActionWithValue(type: QuickActionType, value: String) -> URL? {
        quickActionMessage = nil
        switch type {
        case .message, .call:
            return buildPhoneURL(type: type, phone: value)
        case .email:
            return buildEmailURL(email: value)
        }
    }

    private func buildPhoneURL(type: QuickActionType, phone: String) -> URL? {
        let sanitizedPhone = sanitize(phone)
        let scheme = type == .message ? "sms" : "tel"
        guard let encoded = sanitizedPhone.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(scheme):\(encoded)") else {
            AppLogger.logWarning("Failed to create \(scheme) URL for contact \(person.id)", category: AppLogger.viewModel)
            return nil
        }
        return url
    }

    private func buildEmailURL(email: String) -> URL? {
        guard let encoded = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "mailto:\(encoded)") else {
            AppLogger.logWarning("Failed to create mailto URL for contact \(person.id)", category: AppLogger.viewModel)
            return nil
        }
        return url
    }

    private func savePerson(_ updated: Person) {
        do {
            try personRepository.save(updated)
            person = updated
            load()
            NotificationCenter.default.post(name: .personDidChange, object: updated.id)
        } catch let error as RepositoryError {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "PersonDetailViewModel.savePerson")
            ErrorToastManager.shared.show(AppError(message: error.userMessage))
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "PersonDetailViewModel.savePerson (unexpected)")
            ErrorToastManager.shared.show(.saveFailed("PersonDetail"))
        }
    }

    private func fetchSortedEvents() -> [TouchEvent] {
        let calendar = Calendar.current
        return touchRepository.fetchAll(for: person.id).sorted {
            let day0 = calendar.startOfDay(for: $0.at)
            let day1 = calendar.startOfDay(for: $1.at)
            if day0 != day1 { return day0 > day1 }
            return ($0.timeOfDay?.sortOrder ?? 0) > ($1.timeOfDay?.sortOrder ?? 0)
        }
    }

    private func sanitize(_ phone: String) -> String {
        phone.filter { $0.isNumber || $0 == "+" }
    }

}

enum QuickActionType {
    case message
    case call
    case email

    var touchMethod: TouchMethod {
        switch self {
        case .message: return .text
        case .call: return .call
        case .email: return .email
        }
    }
}
