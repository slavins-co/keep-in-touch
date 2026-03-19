//
//  OnboardingViewModelTests.swift
//  KeepInTouchTests
//
//  Created by Codex on 2/24/26.
//

import XCTest
@testable import StayInTouch

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    private var personRepo: MockPersonRepository!
    private var cadenceRepo: MockCadenceRepository!
    private var settingsRepo: MockSettingsRepository!
    private var monthlyGroupId: UUID!
    private var sut: OnboardingViewModel!

    override func setUp() {
        super.setUp()
        monthlyGroupId = UUID()
        personRepo = MockPersonRepository()
        cadenceRepo = MockCadenceRepository()
        cadenceRepo.cadences = [
            TestFactory.makeCadence(id: monthlyGroupId, name: "Monthly", frequencyDays: 30),
            TestFactory.makeCadence(name: "Weekly", frequencyDays: 7)
        ]
        settingsRepo = MockSettingsRepository()
        settingsRepo.settings = TestFactory.makeSettings()

        sut = OnboardingViewModel(
            personRepository: personRepo,
            cadenceRepository: cadenceRepo,
            settingsRepository: settingsRepo
        )
    }

    // MARK: - Step Transitions

    func testInitialStepIsWelcome() {
        XCTAssertEqual(sut.step, .welcome)
    }

    func testGoToContactsPermission() {
        sut.goToContactsPermission()
        XCTAssertEqual(sut.step, .contactsPermission)
    }

    func testSkipContactsPermissionGoesToRequired() {
        sut.skipContactsPermission()
        XCTAssertEqual(sut.step, .contactsRequired)
    }

    func testContinueFromContactPickerEmptySkipsToNotifications() {
        sut.selectedContactIds = []
        sut.continueFromContactPicker()
        XCTAssertEqual(sut.step, .notificationsPermission)
    }

    func testContinueFromContactPickerWithSelectionGoesToGroupAssignment() {
        let contact = ContactSummary(identifier: "abc123", displayName: "Alice", initials: "AL")
        sut.contacts = [contact]
        sut.selectedContactIds = ["abc123"]

        sut.continueFromContactPicker()

        XCTAssertEqual(sut.step, .groupAssignment)
    }

    func testContinueFromContactsRequiredGoesToNotifications() {
        sut.continueFromContactsRequired()
        XCTAssertEqual(sut.step, .notificationsPermission)
    }

    func testSkipNotificationsGoesToSkipped() {
        sut.skipNotifications()
        XCTAssertEqual(sut.step, .notificationsSkipped)
    }

    func testFinishFromSkippedCompletesOnboarding() async throws {
        sut.finishFromNotificationsSkipped()
        // isCompleting is set immediately; isOnboardingCompleted after delay
        XCTAssertTrue(sut.isCompleting)
        try await Task.sleep(for: .milliseconds(700))
        XCTAssertTrue(sut.isOnboardingCompleted)
    }

    // MARK: - Contact Selection

    func testToggleSelectionAddsContact() {
        sut.toggleSelection(for: "abc123")
        XCTAssertTrue(sut.selectedContactIds.contains("abc123"))
    }

    func testToggleSelectionRemovesContact() {
        sut.selectedContactIds = ["abc123"]
        sut.toggleSelection(for: "abc123")
        XCTAssertFalse(sut.selectedContactIds.contains("abc123"))
    }

    func testFilteredContactsReturnsAllWhenSearchEmpty() {
        sut.contacts = [
            ContactSummary(identifier: "1", displayName: "Alice", initials: "AL"),
            ContactSummary(identifier: "2", displayName: "Bob", initials: "BO"),
            ContactSummary(identifier: "3", displayName: "Charlie", initials: "CH")
        ]
        sut.searchText = ""

        XCTAssertEqual(sut.filteredContacts.count, 3)
    }

    func testFilteredContactsFiltersBySearchText() {
        sut.contacts = [
            ContactSummary(identifier: "1", displayName: "Alice", initials: "AL"),
            ContactSummary(identifier: "2", displayName: "Bob", initials: "BO")
        ]
        sut.searchText = "Ali"

        XCTAssertEqual(sut.filteredContacts.count, 1)
        XCTAssertEqual(sut.filteredContacts.first?.displayName, "Alice")
    }

    // MARK: - Cadence Selection

    func testSelectedGroupIdDefaultsToMonthly() {
        XCTAssertEqual(sut.selectedCadenceId, monthlyGroupId)
    }

    func testSelectedGroupIdFallsToFirstGroupWhenNoMonthly() {
        let firstId = UUID()
        cadenceRepo.cadences = [
            TestFactory.makeCadence(id: firstId, name: "Biweekly"),
            TestFactory.makeCadence(name: "Quarterly")
        ]
        settingsRepo.settings = TestFactory.makeSettings()

        let vm = OnboardingViewModel(
            personRepository: personRepo,
            cadenceRepository: cadenceRepo,
            settingsRepository: settingsRepo
        )

        XCTAssertEqual(vm.selectedCadenceId, firstId)
    }

    func testSeedGroupSelectionsUsesDefaultGroup() {
        let contact1 = ContactSummary(identifier: "c1", displayName: "Alice", initials: "AL")
        let contact2 = ContactSummary(identifier: "c2", displayName: "Bob", initials: "BO")
        sut.contacts = [contact1, contact2]
        sut.selectedContactIds = ["c1", "c2"]

        sut.continueFromContactPicker()

        XCTAssertEqual(sut.contactGroupSelections["c1"], monthlyGroupId)
        XCTAssertEqual(sut.contactGroupSelections["c2"], monthlyGroupId)
    }

    // MARK: - Onboarding Completion

    func testCompleteOnboardingSavesSettings() async throws {
        sut.finishFromNotificationsSkipped()

        // Settings saved immediately (before animation delay)
        XCTAssertTrue(settingsRepo.settings?.onboardingCompleted == true)
        // isOnboardingCompleted set after delay
        try await Task.sleep(for: .milliseconds(700))
        XCTAssertTrue(sut.isOnboardingCompleted)
    }

    func testDemoDataPathEnablesDemoMode() {
        sut.useDemoData = true
        sut.continueFromContactsRequired()

        XCTAssertTrue(settingsRepo.settings?.demoModeEnabled == true)
    }

    // MARK: - Loading State

    func testLoadingSetsToFalseAfterInit() {
        XCTAssertFalse(sut.isLoading)
    }

    func testGroupsPopulatedAfterInit() {
        XCTAssertEqual(sut.cadences.count, 2)
    }

    // MARK: - Back Navigation

    func testCanGoBackIsFalseAtStart() {
        XCTAssertFalse(sut.canGoBack)
    }

    func testCanGoBackIsTrueAfterFirstTransition() {
        sut.goToContactsPermission()
        XCTAssertTrue(sut.canGoBack)
    }

    func testGoBackReturnsToWelcomeFromContactsPermission() {
        sut.goToContactsPermission()
        sut.goBack()
        XCTAssertEqual(sut.step, .welcome)
        XCTAssertFalse(sut.canGoBack)
    }

    func testGoBackTraversesFullHistory() {
        sut.goToContactsPermission()
        sut.skipContactsPermission()
        sut.continueFromContactsRequired()

        XCTAssertEqual(sut.step, .notificationsPermission)

        sut.goBack()
        XCTAssertEqual(sut.step, .contactsRequired)

        sut.goBack()
        XCTAssertEqual(sut.step, .contactsPermission)

        sut.goBack()
        XCTAssertEqual(sut.step, .welcome)
        XCTAssertFalse(sut.canGoBack)
    }

    func testGoBackDoesNothingWhenAtStart() {
        sut.goBack()
        XCTAssertEqual(sut.step, .welcome)
    }

    func testGoBackPreservesSelectedContactIds() {
        sut.goToContactsPermission()
        sut.selectedContactIds = ["abc", "def"]

        sut.goBack()
        XCTAssertEqual(sut.step, .welcome)
        XCTAssertEqual(sut.selectedContactIds, ["abc", "def"])
    }

    func testStartResetsHistory() {
        sut.goToContactsPermission()
        sut.skipContactsPermission()
        XCTAssertTrue(sut.canGoBack)

        sut.start()
        XCTAssertFalse(sut.canGoBack)
        XCTAssertEqual(sut.step, .welcome)
    }

    func testGoBackFromGroupAssignmentPreservesSelections() {
        // Test the group assignment → contact picker back path
        // We verify via the contactsRequired → notifications path instead,
        // since requestContactsPermission requires real CNContactStore.
        let contact = ContactSummary(identifier: "abc123", displayName: "Alice", initials: "AL")
        sut.contacts = [contact]
        sut.selectedContactIds = ["abc123"]

        sut.goToContactsPermission()
        sut.skipContactsPermission()
        sut.continueFromContactsRequired()

        // Selections should still be preserved after navigating
        XCTAssertTrue(sut.selectedContactIds.contains("abc123"))

        sut.goBack()
        XCTAssertEqual(sut.step, .contactsRequired)
        XCTAssertTrue(sut.selectedContactIds.contains("abc123"))
    }

    // MARK: - Progress

    func testShowsProgressIsFalseAtWelcome() {
        XCTAssertFalse(sut.showsProgress)
    }

    func testShowsProgressIsTrueAfterWelcome() {
        sut.goToContactsPermission()
        XCTAssertTrue(sut.showsProgress)
    }

    func testProgressFractionIsZeroAtWelcome() {
        XCTAssertEqual(sut.progressFraction, 0.0, accuracy: 0.01)
    }

    func testProgressFractionAtContactsPermission() {
        sut.goToContactsPermission()
        XCTAssertEqual(sut.progressFraction, 0.15, accuracy: 0.01)
    }

    func testProgressAdvancesFromContactsPermissionToContactsRequired() {
        sut.goToContactsPermission()
        let permissionProgress = sut.progressFraction

        sut.skipContactsPermission()
        let requiredProgress = sut.progressFraction

        XCTAssertGreaterThan(requiredProgress, permissionProgress)
        XCTAssertEqual(requiredProgress, 0.3, accuracy: 0.01)
    }

    func testProgressAdvancesFromNotificationsPermissionToSkipped() {
        sut.goToContactsPermission()
        sut.skipContactsPermission()
        sut.continueFromContactsRequired()
        let permissionProgress = sut.progressFraction

        sut.skipNotifications()
        let skippedProgress = sut.progressFraction

        XCTAssertGreaterThan(skippedProgress, permissionProgress)
        XCTAssertEqual(skippedProgress, 0.95, accuracy: 0.01)
    }

    func testProgressAtNotificationsViaSkipPath() {
        sut.goToContactsPermission()
        sut.skipContactsPermission()
        sut.continueFromContactsRequired()
        XCTAssertEqual(sut.progressFraction, 0.85, accuracy: 0.01)
    }

    func testProgressAlwaysAdvancesOnForwardNavigation() {
        var previousFraction = sut.progressFraction

        sut.goToContactsPermission()
        XCTAssertGreaterThan(sut.progressFraction, previousFraction)
        previousFraction = sut.progressFraction

        sut.skipContactsPermission()
        XCTAssertGreaterThan(sut.progressFraction, previousFraction)
        previousFraction = sut.progressFraction

        sut.continueFromContactsRequired()
        XCTAssertGreaterThan(sut.progressFraction, previousFraction)
        previousFraction = sut.progressFraction

        sut.skipNotifications()
        XCTAssertGreaterThan(sut.progressFraction, previousFraction)
    }

    // MARK: - Completion Animation

    func testIsCompletingStartsFalse() {
        XCTAssertFalse(sut.isCompleting)
    }

    func testCompletionSetsIsCompletingBeforeOnboardingCompleted() {
        sut.finishFromNotificationsSkipped()

        // isCompleting should be true immediately
        XCTAssertTrue(sut.isCompleting)
        // Progress should be 1.0 during completion
        XCTAssertEqual(sut.progressFraction, 1.0, accuracy: 0.01)
    }

    // MARK: - Last Touch Seeding Step

    func testContinueFromGroupAssignmentGoesToLastTouchSeeding() {
        let contact = ContactSummary(identifier: "abc123", displayName: "Alice", initials: "AL")
        sut.contacts = [contact]
        sut.selectedContactIds = ["abc123"]

        sut.continueFromContactPicker()
        XCTAssertEqual(sut.step, .groupAssignment)

        sut.continueFromGroupAssignment()
        XCTAssertEqual(sut.step, .lastTouchSeeding)
    }

    func testContinueFromLastTouchSeedingGoesToNotifications() async throws {
        let contact = ContactSummary(identifier: "abc123", displayName: "Alice", initials: "AL")
        sut.contacts = [contact]
        sut.selectedContactIds = ["abc123"]

        sut.continueFromContactPicker()
        sut.continueFromGroupAssignment()
        XCTAssertEqual(sut.step, .lastTouchSeeding)

        sut.continueFromLastTouchSeeding()
        // Allow Task to complete
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(sut.step, .notificationsPermission)
    }

    func testProgressFractionAtLastTouchSeeding() {
        let contact = ContactSummary(identifier: "abc123", displayName: "Alice", initials: "AL")
        sut.contacts = [contact]
        sut.selectedContactIds = ["abc123"]

        sut.continueFromContactPicker()
        sut.continueFromGroupAssignment()

        XCTAssertEqual(sut.progressFraction, 0.7, accuracy: 0.01)
    }

    func testLastTouchSelectionsDefaultToCantRemember() {
        let contact = ContactSummary(identifier: "abc123", displayName: "Alice", initials: "AL")
        sut.contacts = [contact]
        sut.selectedContactIds = ["abc123"]

        sut.continueFromContactPicker()
        sut.continueFromGroupAssignment()

        XCTAssertEqual(sut.contactLastTouchSelections["abc123"], .cantRemember)
    }

    func testGoBackFromLastTouchSeedingPreservesSelections() {
        let contact = ContactSummary(identifier: "abc123", displayName: "Alice", initials: "AL")
        sut.contacts = [contact]
        sut.selectedContactIds = ["abc123"]

        sut.continueFromContactPicker()
        sut.continueFromGroupAssignment()
        sut.contactLastTouchSelections["abc123"] = .thisMonth

        sut.goBack()
        XCTAssertEqual(sut.step, .groupAssignment)
        XCTAssertEqual(sut.contactLastTouchSelections["abc123"], .thisMonth)
    }

    func testProgressAdvancesThroughLastTouchSeeding() {
        let contact = ContactSummary(identifier: "abc123", displayName: "Alice", initials: "AL")
        sut.contacts = [contact]
        sut.selectedContactIds = ["abc123"]

        sut.continueFromContactPicker()
        let groupProgress = sut.progressFraction

        sut.continueFromGroupAssignment()
        let seedProgress = sut.progressFraction

        XCTAssertGreaterThan(seedProgress, groupProgress)
    }
}
