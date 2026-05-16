//
//  WalkthroughCoordinator.swift
//  KeepInTouch
//
//  Drives the post-onboarding tutorial walkthrough state machine.
//  Persists tutorialCompleted=true only on terminal states (complete or skip).
//

import Foundation

@MainActor
final class WalkthroughCoordinator: ObservableObject {
    @Published private(set) var currentStep: WalkthroughStep?
    @Published private(set) var stepHistory: [WalkthroughStep] = []
    @Published private(set) var isPresentingDemoDetail: Bool = false
    @Published private(set) var didComplete: Bool = false

    static let currentVersion = "1.0"

    static let stepOrder: [WalkthroughStep] = [
        .welcome,
        .homeOverdue, .homeDueSoon, .homeAllGood,
        .homeFilters, .homeSearch, .homeSwipeDemo,
        .detailHero, .detailLogTouch, .detailCadenceGroupTags,
        .detailSettingsMenu, .detailWrap,
    ]

    private let settingsRepository: AppSettingsRepository
    private let haptics: WalkthroughHaptics

    init(
        settingsRepository: AppSettingsRepository,
        haptics: WalkthroughHaptics = DefaultWalkthroughHaptics()
    ) {
        self.settingsRepository = settingsRepository
        self.haptics = haptics
    }

    var canGoBack: Bool { !stepHistory.isEmpty }

    var isInDetailPhase: Bool {
        currentStep?.phase == .detailB
    }

    func start() {
        stepHistory = []
        isPresentingDemoDetail = false
        didComplete = false
        currentStep = .welcome
    }

    func advance() {
        guard let step = currentStep else { return }
        haptics.soft()
        guard let index = Self.stepOrder.firstIndex(of: step),
              index + 1 < Self.stepOrder.count else {
            markComplete()
            return
        }
        let next = Self.stepOrder[index + 1]
        stepHistory.append(step)
        // Crossing the A → B boundary navigates into the demo PersonDetail.
        if step == .homeSwipeDemo && next == .detailHero {
            isPresentingDemoDetail = true
        }
        currentStep = next
    }

    func back() {
        guard let previous = stepHistory.popLast() else { return }
        // Crossing the B → A boundary backwards dismisses the demo PersonDetail.
        if currentStep == .detailHero && previous == .homeSwipeDemo {
            isPresentingDemoDetail = false
        }
        currentStep = previous
    }

    func skip() {
        haptics.soft()
        markComplete()
    }

    private func markComplete() {
        currentStep = nil
        stepHistory = []
        isPresentingDemoDetail = false
        didComplete = true
        persistCompletion()
    }

    private func persistCompletion() {
        guard var settings = settingsRepository.fetch() else { return }
        settings.tutorialCompleted = true
        settings.tutorialVersion = Self.currentVersion
        do {
            try settingsRepository.save(settings)
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        } catch {
            AppLogger.logError(
                error,
                category: AppLogger.viewModel,
                context: "WalkthroughCoordinator.persistCompletion"
            )
            ErrorToastManager.shared.show(.saveFailed("Tutorial"))
        }
    }
}
