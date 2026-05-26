//
//  PersonDetailViewModel.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

@MainActor
final class PersonDetailViewModel: ObservableObject {
    /// Operating mode. `.preview` is used by the tutorial walkthrough to render
    /// PersonDetailView against an in-memory demo contact without touching the
    /// real repositories. All mutation methods early-return in `.preview` mode.
    enum Mode {
        case normal
        case preview(PreviewData)
    }

    struct PreviewData {
        let cadence: Cadence
        let cadences: [Cadence]
        let groups: [Group]
        let touchEvents: [TouchEvent]
        let phone: String?
        let email: String?
        let contactBirthday: Birthday?
    }

    @Published private(set) var person: Person
    @Published private(set) var cadence: Cadence?
    @Published private(set) var cadences: [Cadence] = []
    @Published private(set) var groups: [Group] = []
    @Published private(set) var availableGroups: [Group] = []
    @Published private(set) var touchEvents: [TouchEvent] = []
    @Published private(set) var phone: String?
    @Published private(set) var email: String?
    @Published private(set) var phoneNumbers: [ContactsFetcher.LabeledValue] = []
    @Published private(set) var emailAddresses: [ContactsFetcher.LabeledValue] = []
    @Published var contactBirthday: Birthday?
    @Published var quickActionMessage: String?
    @Published var showPhonePicker = false
    @Published var showEmailPicker = false
    /// What to do with the phone the user picks from `showPhonePicker`.
    /// Set by `routeAction` when a multi-phone contact triggers the dialog;
    /// cleared by `cancelPendingPhonePicker` when the dialog completes or cancels.
    private(set) var pendingPhoneRouting: PhoneRouting?

    let mode: Mode
    private let personRepository: PersonRepository
    private let cadenceRepository: CadenceRepository
    private let groupRepository: GroupRepository
    private let touchRepository: TouchEventRepository
    private let messengerAvailability: MessengerAvailabilityChecking

    var isPreview: Bool {
        if case .preview = mode { return true }
        return false
    }

    init(
        person: Person,
        mode: Mode = .normal,
        personRepository: PersonRepository = CoreDataPersonRepository(context: CoreDataStack.shared.viewContext),
        cadenceRepository: CadenceRepository = CoreDataCadenceRepository(context: CoreDataStack.shared.viewContext),
        groupRepository: GroupRepository = CoreDataGroupRepository(context: CoreDataStack.shared.viewContext),
        touchRepository: TouchEventRepository = CoreDataTouchEventRepository(context: CoreDataStack.shared.viewContext),
        messengerAvailability: MessengerAvailabilityChecking = SystemMessengerAvailability()
    ) {
        self.person = person
        self.mode = mode
        self.personRepository = personRepository
        self.cadenceRepository = cadenceRepository
        self.groupRepository = groupRepository
        self.touchRepository = touchRepository
        self.messengerAvailability = messengerAvailability
        self.availableMessengers = messengerAvailability.availableMessengers()
        load()
        if case .normal = mode {
            AnalyticsService.track("person.viewed")
        }
    }

    convenience init(person: Person, dependencies: AppDependencies) {
        self.init(
            person: person,
            personRepository: dependencies.personRepository,
            cadenceRepository: dependencies.cadenceRepository,
            groupRepository: dependencies.groupRepository,
            touchRepository: dependencies.touchEventRepository
        )
    }

    func load() {
        if case let .preview(data) = mode {
            cadence = data.cadence
            cadences = data.cadences
            groups = data.groups
            availableGroups = []
            touchEvents = data.touchEvents
            phone = data.phone
            email = data.email
            contactBirthday = data.contactBirthday
            return
        }
        if let refreshed = personRepository.fetch(id: person.id) {
            person = refreshed
        }
        cadences = cadenceRepository.fetchAll()
        cadence = cadenceRepository.fetch(id: person.cadenceId)
        groups = groupRepository.fetchAll()
        availableGroups = groups.filter { !person.groupIds.contains($0.id) }
        touchEvents = fetchSortedEvents()
    }

    func refreshContactInfo() async {
        if isPreview { return }
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
        if isPreview { return }
        var updated = person
        updated.birthday = birthday
        updated.modifiedAt = Date()
        savePerson(updated)
    }

    func setBirthdayNotificationsEnabled(_ enabled: Bool) {
        if isPreview { return }
        AnalyticsService.track("person.birthdayNotifications.toggled", parameters: ["enabled": String(enabled)])
        var updated = person
        updated.birthdayNotificationsEnabled = enabled
        updated.modifiedAt = Date()
        savePerson(updated)
    }

    func changeCadence(to cadenceId: UUID) {
        if isPreview { return }
        let updated = AssignCadenceUseCase().assign(person: person, to: cadenceId)
        // savePerson refreshes the cadence in-place when cadenceId changes.
        savePerson(updated)
    }

    func togglePause() {
        if isPreview { return }
        var updated = person
        updated.isPaused.toggle()
        updated.modifiedAt = Date()
        AnalyticsService.track(updated.isPaused ? "person.paused" : "person.resumed")
        savePerson(updated)
    }

    func setNotificationsMuted(_ muted: Bool) {
        if isPreview { return }
        var updated = person
        updated.notificationsMuted = muted
        updated.modifiedAt = Date()
        savePerson(updated)
    }

    func setCustomBreachTime(_ time: LocalTime?) {
        if isPreview { return }
        var updated = person
        updated.customBreachTime = time
        updated.modifiedAt = Date()
        savePerson(updated)
    }

    func saveNextTouchNotes(_ notes: String?) {
        if isPreview { return }
        var updated = person
        updated.nextTouchNotes = notes?.isEmpty == true ? nil : notes
        updated.modifiedAt = Date()
        savePerson(updated)
    }

    func snooze(until date: Date) {
        if isPreview { return }
        AnalyticsService.track("person.snoozed")
        var updated = person
        updated.snoozedUntil = date
        updated.modifiedAt = Date()
        savePerson(updated)
    }

    func clearSnooze() {
        if isPreview { return }
        var updated = person
        updated.snoozedUntil = nil
        updated.modifiedAt = Date()
        savePerson(updated)
    }

    func setCustomDueDate(_ date: Date?) {
        if isPreview { return }
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
        if isPreview { return }
        var updated = person
        updated.customBreachTime = nil
        updated.notificationsMuted = false
        updated.modifiedAt = Date()
        savePerson(updated)
    }

    func resumeAndUpdateLastTouch(date: Date?) {
        if isPreview { return }
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

    func addGroup(_ group: Group) {
        if isPreview { return }
        guard !person.groupIds.contains(group.id) else { return }
        var updated = person
        updated.groupIds.append(group.id)
        updated.modifiedAt = Date()
        // savePerson refreshes availableGroups in-place when groupIds changes.
        savePerson(updated)
    }

    func removeGroup(_ group: Group) {
        if isPreview { return }
        var updated = person
        updated.groupIds.removeAll { $0 == group.id }
        updated.modifiedAt = Date()
        // savePerson refreshes availableGroups in-place when groupIds changes.
        savePerson(updated)
    }

    func logTouch(method: TouchMethod, notes: String?, date: Date, timeOfDay: TimeOfDay? = nil) {
        if isPreview { return }
        AnalyticsService.track("connection.logged", parameters: ["method": method.rawValue])
        let now = Date()
        let touch = TouchEvent(
            id: UUID(),
            personId: person.id,
            at: date,
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

        // Newest-wins: a back-dated touch should not overwrite the
        // denormalized headline if a more recent touch already exists.
        let updated = BulkLogTouchUseCase.applyTouch(to: person, event: touch, now: now)
        savePerson(updated)

        touchEvents = fetchSortedEvents()
    }

    func updateTouch(_ touch: TouchEvent, method: TouchMethod, notes: String?, timeOfDay: TimeOfDay? = nil) {
        if isPreview { return }
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
        if isPreview { return }
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

        // Shared with BulkLogTouchUseCase.reconcile so single-event
        // undo and bulk batch-edit run through the same headline
        // recompute logic.
        let updated = BulkLogTouchUseCase.recomputeLastTouch(
            for: person,
            from: touchEvents,
            now: Date()
        )
        savePerson(updated)
    }

    func relinkContact(cnIdentifier: String) {
        if isPreview { return }
        AnalyticsService.track("person.contactRelinked")
        var updated = person
        updated.cnIdentifier = cnIdentifier
        updated.modifiedAt = Date()
        savePerson(updated)
        Task { await refreshContactInfo() }
    }

    func deletePerson() {
        if isPreview { return }
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

    /// Resolves which messenger should handle a `.message` tap for the current person.
    /// Falls back to iMessage when no preference is set.
    var resolvedMessenger: PreferredMessenger {
        person.preferredMessenger ?? .iMessage
    }

    /// Messengers available on this device, used to build the long-press picker.
    /// Cached at init — `canOpenURL` results are stable for the app's lifetime.
    let availableMessengers: [PreferredMessenger]

    /// Persists the user's explicit messenger choice for this person.
    /// We store `nil` for `.iMessage` so a future global default can flip
    /// behavior without per-row migration.
    func setPreferredMessenger(_ messenger: PreferredMessenger) {
        if isPreview { return }
        let toStore: PreferredMessenger? = messenger == .iMessage ? nil : messenger
        guard person.preferredMessenger != toStore else { return }
        var updated = person
        updated.preferredMessenger = toStore
        updated.modifiedAt = Date()
        AnalyticsService.track("person.preferredMessenger.set", parameters: ["value": messenger.rawValue])
        savePerson(updated)
    }

    /// Self-heal: a sticky non-iMessage choice failed to open (likely uninstalled).
    /// Clear the preference and surface a one-time toast.
    func handleFailedMessengerOpen(messenger: PreferredMessenger) {
        if isPreview { return }
        if person.preferredMessenger == messenger && messenger != .iMessage {
            var updated = person
            updated.preferredMessenger = nil
            updated.modifiedAt = Date()
            savePerson(updated)
            quickActionMessage = "Couldn't open \(messenger.displayName). Falling back to iMessage."
        } else {
            quickActionMessage = "Whoops — couldn't open that on this device."
        }
    }

    // MARK: - Phone-action routing
    //
    // The Message and Call buttons share a phone-picker codepath: a contact
    // with multiple numbers stashes the routing intent (which messenger or
    // which call mode the user picked) and shows the picker dialog. When the
    // user picks a number, the View calls back with the routing + value to
    // produce the final URL. `PhoneRouting` encodes the three valid intents
    // so the View doesn't have to coordinate three separate state fields.

    /// What the user wants to do with a phone number once one is selected.
    enum PhoneRouting: Equatable {
        case call
        case faceTime
        case message(explicit: PreferredMessenger?)

        /// TouchMethod to log when this routing succeeds.
        ///
        /// `.call` always logs `.call`; `.faceTime` always logs `.facetime`.
        /// `.message(explicit:)` delegates to `PreferredMessenger.touchMethod`
        /// — after #299 all three text-medium messengers (iMessage, WhatsApp,
        /// Signal) log as `.text`, with the per-contact app preference
        /// preserved on `Person.preferredMessenger`. The `defaultMessenger:`
        /// parameter is retained so the routing→logging boundary stays
        /// explicit at every call site — if a new non-text messenger is
        /// added later that should log distinctly, the contract is already
        /// in place to surface the resolved messenger here.
        func resolvedTouchMethod(defaultMessenger: PreferredMessenger) -> TouchMethod {
            switch self {
            case .call: return .call
            case .faceTime: return .facetime
            case .message(let explicit): return (explicit ?? defaultMessenger).touchMethod
            }
        }
    }

    /// Routes a phone action. Returns the URL when the contact has a single
    /// number; otherwise stashes the routing intent and triggers the phone
    /// picker (`showPhonePicker = true`) — the View's confirmationDialog
    /// callback then resolves via `routeActionWithValue`.
    func routeAction(_ routing: PhoneRouting) -> URL? {
        if isPreview { return nil }
        quickActionMessage = nil
        if phoneNumbers.count > 1 {
            pendingPhoneRouting = routing
            showPhonePicker = true
            return nil
        }
        guard let phone else {
            quickActionMessage = "Whoops — no phone number found."
            return nil
        }
        return buildPhoneActionURL(routing: routing, phone: phone)
    }

    /// Resolves a phone action against a specific number (post-picker).
    func routeActionWithValue(_ routing: PhoneRouting, value: String) -> URL? {
        if isPreview { return nil }
        quickActionMessage = nil
        return buildPhoneActionURL(routing: routing, phone: value)
    }

    /// Clears any pending phone-picker state. Called when the View dismisses
    /// or completes the picker dialog. Keeps `PhoneRouting` state encapsulated.
    func cancelPendingPhonePicker() {
        pendingPhoneRouting = nil
    }

    /// Email is its own codepath — it has its own value picker (multi-email
    /// contact) and doesn't share state with phone actions.
    func openEmailAction() -> URL? {
        if isPreview { return nil }
        quickActionMessage = nil
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

    func openEmailActionWithValue(_ value: String) -> URL? {
        if isPreview { return nil }
        quickActionMessage = nil
        return buildEmailURL(email: value)
    }

    private func buildPhoneActionURL(routing: PhoneRouting, phone: String) -> URL? {
        let url: URL?
        let label: String
        switch routing {
        case .call:
            url = CallerRouter.telURL(phone: phone)
            label = "tel"
        case .faceTime:
            url = CallerRouter.faceTimeURL(phone: phone)
            label = "facetime"
        case .message(let explicit):
            let messenger = explicit ?? resolvedMessenger
            url = MessengerRouter.url(for: messenger, phone: phone)
            label = messenger.rawValue
        }
        if url == nil {
            AppLogger.logWarning("Failed to create \(label) URL for contact \(person.id)", category: AppLogger.viewModel)
            quickActionMessage = "Whoops — couldn't read that phone number."
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

    /// Persists `updated` and refreshes only the derived state whose inputs
    /// actually changed. Avoids the prior `load()` cascade (refetch of person +
    /// cadences + groups + touch events) on every keystroke-grade mutation
    /// (toggle pause, mute, custom breach time, etc.). Posts
    /// `.personDidChange` so downstream observers (NotificationScheduler,
    /// HomeView, ContactsListView) still see every mutation — the debounce on
    /// the scheduler side coalesces bursts without dropping any.
    private func savePerson(_ updated: Person) {
        let previous = person
        do {
            try personRepository.save(updated)
            person = updated

            // Only re-derive caches whose inputs actually changed.
            if previous.cadenceId != updated.cadenceId {
                cadence = cadenceRepository.fetch(id: updated.cadenceId)
            }
            if previous.groupIds != updated.groupIds {
                availableGroups = groups.filter { !updated.groupIds.contains($0.id) }
            }

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
}

/// Which quick-action card the user tapped. Thin intent enum exchanged
/// between the View and ViewModel; routing logic translates this into
/// `PhoneRouting` (Message/Call) or the email codepath.
enum QuickActionType {
    case message
    case call
    case email
}
