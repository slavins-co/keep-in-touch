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
        .homeFilters, .homeSearch,
        .detailHero, .detailQuickActions, .detailLogTouch,
        .detailNextTouchNotes, .detailTimeline,
        .detailCadenceGroupTags, .detailSettingsMenu, .detailWrap,
    ]

    /// Seconds the demo PersonDetail stays visible after the user taps the
    /// wrap CTA, before the cover dismisses. Gives a beat for "this is what
    /// a real contact looks like" to land.
    static let postCompleteHoldDuration: TimeInterval = 2.0

    /// Seconds to wait between setting `isPresentingDemoDetail = false`
    /// (which kicks off the fullScreenCover slide-down) and posting
    /// `.settingsDidChange` (which makes ContentView swap WalkthroughHost
    /// back to plain MainTabView). Without this gap the parent unmount
    /// obliterates the cover mid-animation and the demo PersonDetail
    /// appears to vanish abruptly. iOS's stock cover transition runs ~0.35s.
    static let postDismissAnimationDuration: TimeInterval = 0.5

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
            markComplete(holdDemoDetail: isInDetailPhase)
            return
        }
        let next = Self.stepOrder[index + 1]
        stepHistory.append(step)
        // Crossing the A → B boundary navigates into the demo PersonDetail.
        if step == .homeSearch && next == .detailHero {
            isPresentingDemoDetail = true
        }
        currentStep = next
        postScrollIfNeeded(for: next)
    }

    func back() {
        guard let previous = stepHistory.popLast() else { return }
        // Crossing the B → A boundary backwards dismisses the demo PersonDetail.
        if currentStep == .detailHero && previous == .homeSearch {
            isPresentingDemoDetail = false
        }
        currentStep = previous
        postScrollIfNeeded(for: previous)
    }

    private func postScrollIfNeeded(for step: WalkthroughStep) {
        guard step.phase == .detailB, let anchor = step.anchorID else { return }
        NotificationCenter.default.post(name: .tutorialScrollToAnchor, object: anchor)
    }

    func skip() {
        haptics.soft()
        markComplete(holdDemoDetail: false)
    }

    /// Marks the walkthrough complete. When `holdDemoDetail` is true and the
    /// demo PersonDetail is currently presented, the cover stays visible for
    /// `postCompleteHoldDuration` seconds before dismissing — letting the
    /// "this is a real contact" mental model land before the demo vanishes.
    ///
    /// CRITICAL ordering: the flag is saved IMMEDIATELY (so a crash mid-hold
    /// still records the completion), but `.settingsDidChange` is posted ONLY
    /// after the hold completes. Otherwise `ContentView` would observe the
    /// notification immediately and swap `WalkthroughHost` back to plain
    /// `MainTabView`, which dismounts the `fullScreenCover` and the demo
    /// PersonDetail vanishes before the hold timer fires.
    private func markComplete(holdDemoDetail: Bool) {
        let wasPresentingDemo = isPresentingDemoDetail
        currentStep = nil
        stepHistory = []
        didComplete = true
        saveCompletionFlag()
        TutorialTipGate.update(walkthroughCompleted: true)

        if holdDemoDetail && wasPresentingDemo {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(Self.postCompleteHoldDuration * 1_000_000_000))
                isPresentingDemoDetail = false
                // Wait for the cover slide-down to finish before posting
                // .settingsDidChange. Otherwise the parent unmount tears the
                // cover off mid-animation and Alex appears to vanish abruptly.
                try? await Task.sleep(nanoseconds: UInt64(Self.postDismissAnimationDuration * 1_000_000_000))
                NotificationCenter.default.post(name: .settingsDidChange, object: nil)
            }
        } else if wasPresentingDemo {
            // Skip from detail phase: still let the cover slide down before
            // unmounting the host.
            isPresentingDemoDetail = false
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(Self.postDismissAnimationDuration * 1_000_000_000))
                NotificationCenter.default.post(name: .settingsDidChange, object: nil)
            }
        } else {
            // No cover up (skip from home phase) — safe to post immediately.
            isPresentingDemoDetail = false
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        }
    }

    private func saveCompletionFlag() {
        guard var settings = settingsRepository.fetch() else { return }
        settings.tutorialCompleted = true
        settings.tutorialVersion = Self.currentVersion
        do {
            try settingsRepository.save(settings)
        } catch {
            AppLogger.logError(
                error,
                category: AppLogger.viewModel,
                context: "WalkthroughCoordinator.saveCompletionFlag"
            )
            ErrorToastManager.shared.show(.saveFailed("Tutorial"))
        }
    }
}
