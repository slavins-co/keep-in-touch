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
    @Published private(set) var isPresentingDemoDetail: Bool = false
    private(set) var stepHistory: [WalkthroughStep] = []
    private(set) var didComplete: Bool = false

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

    /// Seconds to wait between starting the fullScreenCover slide-down and
    /// posting `.settingsDidChange` (which makes ContentView swap WalkthroughHost
    /// back to plain MainTabView). Without this gap the parent unmount
    /// obliterates the cover mid-animation. iOS's stock cover transition runs
    /// ~0.35s.
    static let postDismissAnimationDuration: TimeInterval = 0.5

    private let settingsRepository: AppSettingsRepository
    private let hapticsEnabled: Bool

    init(
        settingsRepository: AppSettingsRepository,
        hapticsEnabled: Bool = true
    ) {
        self.settingsRepository = settingsRepository
        self.hapticsEnabled = hapticsEnabled
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
        playHaptic()
        guard let index = Self.stepOrder.firstIndex(of: step),
              index + 1 < Self.stepOrder.count else {
            markComplete()
            return
        }
        let next = Self.stepOrder[index + 1]
        stepHistory.append(step)
        // Crossing the A → B boundary navigates into the demo PersonDetail.
        if step == .homeSearch && next == .detailHero {
            isPresentingDemoDetail = true
        }
        currentStep = next
        postScrollAnchor(for: next)
    }

    func back() {
        guard let previous = stepHistory.popLast() else { return }
        // Crossing the B → A boundary backwards dismisses the demo PersonDetail.
        if currentStep == .detailHero && previous == .homeSearch {
            isPresentingDemoDetail = false
        }
        currentStep = previous
        postScrollAnchor(for: previous)
    }

    func skip() {
        playHaptic()
        markComplete()
    }

    // MARK: - Private

    private func playHaptic() {
        guard hapticsEnabled else { return }
        Haptics.soft()
    }

    private func postScrollAnchor(for step: WalkthroughStep) {
        guard step.phase == .detailB, let anchor = step.anchorID else { return }
        NotificationCenter.default.post(name: .tutorialScrollToAnchor, object: anchor)
    }

    /// Marks the walkthrough complete. Three cases:
    /// - No demo cover up (skip from Home phase): post `.settingsDidChange`
    ///   immediately.
    /// - Wrap-CTA path (`currentStep == .detailWrap`): hold the cover up for
    ///   `postCompleteHoldDuration` so the user gets a beat with the "real
    ///   contact" view, then dismiss + post.
    /// - Skip from Detail phase: dismiss synchronously so callers see the
    ///   flag flip immediately, but defer the notification post by
    ///   `postDismissAnimationDuration` so the cover's slide-down finishes
    ///   before the parent (`WalkthroughHost`) is swapped out by ContentView.
    private func markComplete() {
        // Re-entrancy guard. If the user taps the wrap CTA, then swipe-dismisses
        // the demo cover during the 2s hold, WalkthroughHost's binding fires
        // `skip()` → `markComplete()` a second time while the first call's
        // deferred Task is still in flight. Without this guard the second call
        // saves the flag again, fires another `.settingsDidChange`, and races
        // the first Task. Idempotent: the first call already did everything.
        guard !didComplete else { return }

        let wasPresentingDemo = isPresentingDemoDetail
        let isWrapCompletion = currentStep == .detailWrap

        currentStep = nil
        stepHistory = []
        didComplete = true
        saveCompletionFlag()
        TutorialTipGate.update(walkthroughCompleted: true)

        guard wasPresentingDemo else {
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
            return
        }

        if isWrapCompletion {
            // Hold the cover up, then dismiss + post after the slide-down.
            Task { @MainActor in
                await sleep(Self.postCompleteHoldDuration)
                isPresentingDemoDetail = false
                await sleep(Self.postDismissAnimationDuration)
                NotificationCenter.default.post(name: .settingsDidChange, object: nil)
            }
        } else {
            // Skip-from-detail: dismiss now, post after the slide-down.
            isPresentingDemoDetail = false
            Task { @MainActor in
                await sleep(Self.postDismissAnimationDuration)
                NotificationCenter.default.post(name: .settingsDidChange, object: nil)
            }
        }
    }

    private func sleep(_ seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
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
