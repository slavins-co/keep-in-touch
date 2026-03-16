//
//  FreshStartIntegrationTests.swift
//  KeepInTouchTests
//
//  Tests the Fresh Start feature end-to-end through HomeViewModel,
//  verifying that freshStartReason is set correctly after init()
//  and after load() — the exact path the UI depends on.
//

import XCTest
@testable import StayInTouch

@MainActor
final class FreshStartIntegrationTests: XCTestCase {

    // MARK: - Helpers

    private let cadenceId = UUID()

    private func makePerson(
        name: String,
        lastTouchDaysAgo: Int? = nil,
        isPaused: Bool = false,
        isDemoData: Bool = false
    ) -> Person {
        let now = Date()
        let lastTouch: Date? = lastTouchDaysAgo.flatMap {
            Calendar.current.date(byAdding: .day, value: -$0, to: now)
        }
        return Person(
            id: UUID(),
            cnIdentifier: nil,
            displayName: name,
            initials: String(name.prefix(2)),
            avatarColor: "#FF6B6B",
            cadenceId: cadenceId,
            groupIds: [],
            lastTouchAt: lastTouch,
            lastTouchMethod: nil,
            lastTouchNotes: nil,
            nextTouchNotes: nil,
            isPaused: isPaused,
            isTracked: true,
            notificationsMuted: false,
            customBreachTime: nil,
            snoozedUntil: nil,
            customDueDate: nil,
            birthday: nil,
            birthdayNotificationsEnabled: true,
            contactUnavailable: false,
            isDemoData: isDemoData,
            cadenceAddedAt: Calendar.current.date(byAdding: .day, value: -60, to: now),
            createdAt: now,
            modifiedAt: now,
            sortOrder: 0
        )
    }

    private func makeGroup(frequencyDays: Int = 7) -> Cadence {
        Cadence(
            id: cadenceId,
            name: "Weekly",
            frequencyDays: frequencyDays,
            warningDays: 2,
            colorHex: nil,
            isDefault: true,
            sortOrder: 0,
            createdAt: Date(),
            modifiedAt: Date()
        )
    }

    private func makePromptStore(
        lastAppOpenedDaysAgo: Int? = nil,
        lastDismissedDaysAgo: Int? = nil
    ) -> FreshStartPromptStore {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        var store = FreshStartPromptStore(defaults: defaults)
        if let days = lastAppOpenedDaysAgo {
            store.lastAppOpenedAt = Calendar.current.date(byAdding: .day, value: -days, to: Date())
        }
        if let days = lastDismissedDaysAgo {
            store.lastDismissedAt = Calendar.current.date(byAdding: .day, value: -days, to: Date())
        }
        return store
    }

    private func makeViewModel(
        people: [Person],
        group: Cadence? = nil,
        promptStore: FreshStartPromptStore? = nil
    ) -> HomeViewModel {
        let g = group ?? makeGroup()
        return HomeViewModel(
            personRepository: StubPersonRepository(people: people),
            cadenceRepository: StubCadenceRepository(groups: [g]),
            groupRepository: StubGroupRepository(groups: []),
            settingsRepository: StubSettingsRepository(),
            promptStore: promptStore ?? makePromptStore()
        )
    }

    // MARK: - Core: freshStartReason Set After Init

    func testOverwhelmedReasonSetImmediatelyAfterInit() {
        // 5 out of 6 overdue (83%) with weekly group → overwhelmed
        let people = (1...5).map { makePerson(name: "Overdue \($0)", lastTouchDaysAgo: 30) }
            + [makePerson(name: "Recent", lastTouchDaysAgo: 1)]

        let vm = makeViewModel(people: people)

        // The bug was: freshStartReason was set during init() but the UI's
        // onChange missed it. This test proves the value IS available for
        // the .onAppear check to read.
        XCTAssertEqual(vm.freshStartReason, .overwhelmed,
            "freshStartReason must be set after init() so .onAppear can read it")
    }

    func testOverwhelmedReasonPersistsAfterReload() {
        let people = (1...5).map { makePerson(name: "Overdue \($0)", lastTouchDaysAgo: 30) }
            + [makePerson(name: "Recent", lastTouchDaysAgo: 1)]

        let vm = makeViewModel(people: people)
        // Simulate what HomeView.onAppear does
        vm.load()

        XCTAssertEqual(vm.freshStartReason, .overwhelmed,
            "freshStartReason must remain after load() is called again")
    }

    // MARK: - Threshold Boundaries

    func testExactlyAtThresholdTriggers() {
        // 4/5 = 80% exactly at threshold for small list
        let people = (1...4).map { makePerson(name: "Overdue \($0)", lastTouchDaysAgo: 30) }
            + [makePerson(name: "Recent", lastTouchDaysAgo: 1)]

        let vm = makeViewModel(people: people)
        XCTAssertEqual(vm.freshStartReason, .overwhelmed)
    }

    func testJustBelowThresholdDoesNotTrigger() {
        // 3/5 = 60% below 80% threshold for small list
        let people = (1...3).map { makePerson(name: "Overdue \($0)", lastTouchDaysAgo: 30) }
            + (1...2).map { makePerson(name: "Recent \($0)", lastTouchDaysAgo: 1) }

        let vm = makeViewModel(people: people)
        XCTAssertNil(vm.freshStartReason)
    }

    func testBelowMinimumContactsDoesNotTrigger() {
        // 4 contacts, all overdue — below 5-contact minimum
        let people = (1...4).map { makePerson(name: "Overdue \($0)", lastTouchDaysAgo: 30) }

        let vm = makeViewModel(people: people)
        XCTAssertNil(vm.freshStartReason)
    }

    // MARK: - Inactivity

    func testInactiveReasonWhenAppNotOpenedFor14Days() {
        // 5 contacts, none overdue, but app not opened for 14 days
        let people = (1...5).map { makePerson(name: "Recent \($0)", lastTouchDaysAgo: 1) }
        let store = makePromptStore(lastAppOpenedDaysAgo: 14)

        let vm = makeViewModel(people: people, promptStore: store)
        XCTAssertEqual(vm.freshStartReason, .inactive)
    }

    func testNotInactiveWhenAppOpenedRecently() {
        // 5 contacts, none overdue, app opened 5 days ago
        let people = (1...5).map { makePerson(name: "Recent \($0)", lastTouchDaysAgo: 1) }
        let store = makePromptStore(lastAppOpenedDaysAgo: 5)

        let vm = makeViewModel(people: people, promptStore: store)
        XCTAssertNil(vm.freshStartReason)
    }

    func testBothReasonWhenOverwhelmedAndInactive() {
        let people = (1...5).map { makePerson(name: "Overdue \($0)", lastTouchDaysAgo: 30) }
            + [makePerson(name: "Recent", lastTouchDaysAgo: 1)]
        let store = makePromptStore(lastAppOpenedDaysAgo: 20)

        let vm = makeViewModel(people: people, promptStore: store)
        XCTAssertEqual(vm.freshStartReason, .both)
    }

    // MARK: - Cooldown

    func testCooldownPreventsPromptEvenWhenOverwhelmed() {
        let people = (1...6).map { makePerson(name: "Overdue \($0)", lastTouchDaysAgo: 30) }
        let store = makePromptStore(lastDismissedDaysAgo: 15) // within 30-day cooldown

        let vm = makeViewModel(people: people, promptStore: store)
        XCTAssertNil(vm.freshStartReason)
    }

    func testCooldownExpiredAllowsPrompt() {
        let people = (1...6).map { makePerson(name: "Overdue \($0)", lastTouchDaysAgo: 30) }
        let store = makePromptStore(lastDismissedDaysAgo: 31) // past 30-day cooldown

        let vm = makeViewModel(people: people, promptStore: store)
        XCTAssertEqual(vm.freshStartReason, .overwhelmed)
    }

    // MARK: - Demo Data Exclusion

    func testDemoDataContactsExcludedFromDetection() {
        // 5 overdue demo contacts + 1 real recent → should NOT trigger
        // because demo contacts are filtered out, leaving only 1 tracked
        let demoOverdue = (1...5).map { makePerson(name: "Demo \($0)", lastTouchDaysAgo: 30, isDemoData: true) }
        let realRecent = [makePerson(name: "Real", lastTouchDaysAgo: 1)]

        let vm = makeViewModel(people: demoOverdue + realRecent)
        XCTAssertNil(vm.freshStartReason,
            "Demo contacts should be excluded from fresh start detection")
    }

    func testMixedDemoAndRealCountsOnlyReal() {
        // 4 real overdue + 1 real recent + 5 demo overdue
        // Real: 4/5 = 80% → overwhelmed (demo excluded from both counts)
        let realOverdue = (1...4).map { makePerson(name: "RealOverdue \($0)", lastTouchDaysAgo: 30) }
        let realRecent = [makePerson(name: "RealRecent", lastTouchDaysAgo: 1)]
        let demoOverdue = (1...5).map { makePerson(name: "Demo \($0)", lastTouchDaysAgo: 30, isDemoData: true) }

        let vm = makeViewModel(people: realOverdue + realRecent + demoOverdue)
        XCTAssertEqual(vm.freshStartReason, .overwhelmed)
    }

    // MARK: - Paused Contacts

    func testPausedContactsInDenominatorButNotNumerator() {
        // 4 overdue + 1 recent + 1 paused (overdue but paused)
        // allPeople = 6, but overduePeople excludes paused → 4
        // tracked (non-demo) = 6, overdue (non-demo from service) = 4
        // 4/6 = 67% — below 80% threshold for <10 contacts
        let overdue = (1...4).map { makePerson(name: "Overdue \($0)", lastTouchDaysAgo: 30) }
        let recent = [makePerson(name: "Recent", lastTouchDaysAgo: 1)]
        let paused = [makePerson(name: "Paused", lastTouchDaysAgo: 30, isPaused: true)]

        let vm = makeViewModel(people: overdue + recent + paused)
        XCTAssertNil(vm.freshStartReason,
            "Paused contacts inflate denominator, diluting the overdue ratio")
    }

    // MARK: - Dismiss and Execute

    func testDismissClearsReason() {
        let people = (1...6).map { makePerson(name: "Overdue \($0)", lastTouchDaysAgo: 30) }
        let vm = makeViewModel(people: people)
        XCTAssertNotNil(vm.freshStartReason)

        vm.dismissFreshStartPrompt()
        XCTAssertNil(vm.freshStartReason)
    }

    func testDismissRecordsCooldown() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = FreshStartPromptStore(defaults: defaults)
        let people = (1...6).map { makePerson(name: "Overdue \($0)", lastTouchDaysAgo: 30) }
        let vm = makeViewModel(people: people, promptStore: store)

        vm.dismissFreshStartPrompt()

        // After dismissal, lastDismissedAt should be set
        let refreshedStore = FreshStartPromptStore(defaults: defaults)
        XCTAssertNotNil(refreshedStore.lastDismissedAt)
    }

    // MARK: - Medium/Large Tier Thresholds Through ViewModel

    func testMediumTierThresholdThroughViewModel() {
        // 10 contacts, 7/10 = 70% at threshold for medium list
        let overdue = (1...7).map { makePerson(name: "Overdue \($0)", lastTouchDaysAgo: 30) }
        let recent = (1...3).map { makePerson(name: "Recent \($0)", lastTouchDaysAgo: 1) }

        let vm = makeViewModel(people: overdue + recent)
        XCTAssertEqual(vm.freshStartReason, .overwhelmed)
    }

    func testLargeTierThresholdThroughViewModel() {
        // 20 contacts, 12/20 = 60% at threshold for large list
        let overdue = (1...12).map { makePerson(name: "Overdue \($0)", lastTouchDaysAgo: 30) }
        let recent = (1...8).map { makePerson(name: "Recent \($0)", lastTouchDaysAgo: 1) }

        let vm = makeViewModel(people: overdue + recent)
        XCTAssertEqual(vm.freshStartReason, .overwhelmed)
    }
}

// MARK: - Stub Repositories

private struct StubPersonRepository: PersonRepository {
    let people: [Person]
    func fetch(id: UUID) -> Person? { people.first { $0.id == id } }
    func fetchAll() -> [Person] { people }
    func fetchTracked(includePaused: Bool) -> [Person] {
        people.filter { $0.isTracked && (includePaused || !$0.isPaused) }
    }
    func fetchByCadence(id: UUID, includePaused: Bool) -> [Person] {
        fetchTracked(includePaused: includePaused).filter { $0.cadenceId == id }
    }
    func fetchByGroup(id: UUID, includePaused: Bool) -> [Person] {
        fetchTracked(includePaused: includePaused).filter { $0.groupIds.contains(id) }
    }
    func searchByName(_ query: String, includePaused: Bool) -> [Person] {
        fetchTracked(includePaused: includePaused).filter { $0.displayName.localizedCaseInsensitiveContains(query) }
    }
    func fetchOverdue(referenceDate: Date) -> [Person] { [] }
    func save(_ person: Person) throws {}
    func batchSave(_ persons: [Person]) throws {}
    func delete(id: UUID) throws {}
}

private struct StubCadenceRepository: CadenceRepository {
    let groups: [Cadence]
    func fetch(id: UUID) -> Cadence? { groups.first { $0.id == id } }
    func fetchAll() -> [Cadence] { groups }
    func fetchDefaultGroups() -> [Cadence] { groups.filter { $0.isDefault } }
    func save(_ group: Cadence) throws {}
    func batchSave(_ groups: [Cadence]) throws {}
    func delete(id: UUID) throws {}
}

private struct StubGroupRepository: GroupRepository {
    let groups: [Group]
    func fetch(id: UUID) -> Group? { groups.first { $0.id == id } }
    func fetchAll() -> [Group] { groups }
    func save(_ group: Group) throws {}
    func batchSave(_ groups: [Group]) throws {}
    func delete(id: UUID) throws {}
}

private struct StubSettingsRepository: AppSettingsRepository {
    func fetch() -> AppSettings? {
        AppSettings(
            id: AppSettings.singletonId,
            theme: .light,
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
            hideContactNamesInNotifications: false,
            birthdayNotificationsEnabled: false,
            birthdayNotificationTime: LocalTime(hour: 9, minute: 0),
            birthdayIgnoreSnoozePause: true,
            lastContactsSyncAt: nil,
            onboardingCompleted: false,
            appVersion: ""
        )
    }
    func save(_ settings: AppSettings) throws {}
}
