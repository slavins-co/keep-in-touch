//
//  WalkthroughCoordinatorTests.swift
//  KeepInTouchTests
//
//  Unit tests for the tutorial walkthrough state machine.
//

import XCTest
@testable import StayInTouch

@MainActor
final class WalkthroughCoordinatorTests: XCTestCase {
    private var settingsRepo: MockSettingsRepository!
    private var coordinator: WalkthroughCoordinator!

    override func setUp() {
        super.setUp()
        settingsRepo = MockSettingsRepository()
        settingsRepo.settings = MockSettingsRepository.makeSettings()
        coordinator = WalkthroughCoordinator(
            settingsRepository: settingsRepo,
            haptics: NoOpWalkthroughHaptics()
        )
    }

    // MARK: - start

    func test_start_setsWelcomeAndClearsHistory() {
        coordinator.start()
        XCTAssertEqual(coordinator.currentStep, .welcome)
        XCTAssertTrue(coordinator.stepHistory.isEmpty)
        XCTAssertFalse(coordinator.isPresentingDemoDetail)
        XCTAssertFalse(coordinator.didComplete)
    }

    // MARK: - advance

    func test_advance_walksThroughAllStepsInOrder() {
        coordinator.start()
        let expected: [WalkthroughStep] = [
            .welcome, .homeOverdue, .homeDueSoon, .homeAllGood,
            .homeFilters, .homeSearch, .homeSwipeDemo,
            .detailHero, .detailLogTouch, .detailCadenceGroupTags,
            .detailSettingsMenu, .detailWrap,
        ]
        for step in expected {
            XCTAssertEqual(coordinator.currentStep, step)
            coordinator.advance()
        }
        XCTAssertNil(coordinator.currentStep)
        XCTAssertTrue(coordinator.didComplete)
    }

    func test_advance_acrossAtoBBoundary_setsIsPresentingDemoDetail() {
        coordinator.start()
        for _ in 0..<6 { coordinator.advance() }
        XCTAssertEqual(coordinator.currentStep, .homeSwipeDemo)
        XCTAssertFalse(coordinator.isPresentingDemoDetail)
        coordinator.advance()
        XCTAssertEqual(coordinator.currentStep, .detailHero)
        XCTAssertTrue(coordinator.isPresentingDemoDetail)
    }

    func test_advance_atFinalStep_marksComplete_persistsFlag() {
        coordinator.start()
        for _ in 0..<11 { coordinator.advance() }
        XCTAssertEqual(coordinator.currentStep, .detailWrap)
        XCTAssertEqual(settingsRepo.saveCount, 0)
        coordinator.advance()
        XCTAssertNil(coordinator.currentStep)
        XCTAssertTrue(coordinator.didComplete)
        XCTAssertEqual(settingsRepo.saveCount, 1)
        XCTAssertTrue(settingsRepo.settings?.tutorialCompleted ?? false)
        XCTAssertEqual(settingsRepo.settings?.tutorialVersion, WalkthroughCoordinator.currentVersion)
    }

    // MARK: - back

    func test_back_popsHistoryAndRestoresStep() {
        coordinator.start()
        coordinator.advance()
        coordinator.advance()
        XCTAssertEqual(coordinator.currentStep, .homeDueSoon)
        coordinator.back()
        XCTAssertEqual(coordinator.currentStep, .homeOverdue)
    }

    func test_back_atFirstStep_isNoOp() {
        coordinator.start()
        coordinator.back()
        XCTAssertEqual(coordinator.currentStep, .welcome)
    }

    func test_back_acrossBtoABoundary_dismissesDemoDetail() {
        coordinator.start()
        for _ in 0..<7 { coordinator.advance() }
        XCTAssertEqual(coordinator.currentStep, .detailHero)
        XCTAssertTrue(coordinator.isPresentingDemoDetail)
        coordinator.back()
        XCTAssertEqual(coordinator.currentStep, .homeSwipeDemo)
        XCTAssertFalse(coordinator.isPresentingDemoDetail)
    }

    // MARK: - skip

    func test_skip_fromAnyStep_marksCompleteAndPersists() {
        coordinator.start()
        coordinator.advance()
        coordinator.advance()
        coordinator.skip()
        XCTAssertNil(coordinator.currentStep)
        XCTAssertTrue(coordinator.didComplete)
        XCTAssertEqual(settingsRepo.saveCount, 1)
        XCTAssertTrue(settingsRepo.settings?.tutorialCompleted ?? false)
    }

    func test_skip_fromDetailPhase_clearsIsPresentingDemoDetail() {
        coordinator.start()
        for _ in 0..<7 { coordinator.advance() }
        XCTAssertTrue(coordinator.isPresentingDemoDetail)
        coordinator.skip()
        XCTAssertFalse(coordinator.isPresentingDemoDetail)
        XCTAssertTrue(coordinator.didComplete)
    }

    // MARK: - phase helpers

    func test_isInDetailPhase_reflectsCurrentStep() {
        coordinator.start()
        XCTAssertFalse(coordinator.isInDetailPhase)
        for _ in 0..<7 { coordinator.advance() }
        XCTAssertTrue(coordinator.isInDetailPhase)
    }

    func test_canGoBack_reflectsStepHistory() {
        coordinator.start()
        XCTAssertFalse(coordinator.canGoBack)
        coordinator.advance()
        XCTAssertTrue(coordinator.canGoBack)
    }
}

// MARK: - Test helpers

private extension MockSettingsRepository {
    static func makeSettings() -> AppSettings {
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
            hideContactNamesInNotifications: false,
            birthdayNotificationsEnabled: false,
            birthdayNotificationTime: LocalTime(hour: 9, minute: 0),
            birthdayIgnoreSnoozePause: true,
            lastContactsSyncAt: nil,
            onboardingCompleted: true,
            appVersion: ""
        )
    }
}
