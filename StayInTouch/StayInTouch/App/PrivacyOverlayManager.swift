//
//  PrivacyOverlayManager.swift
//  KeepInTouch
//
//  Adds a UIVisualEffectView blur to the foreground-active scene's key
//  window when the app resigns active, so the snapshot iOS captures for
//  the app switcher does not reveal contact data. The blur is removed
//  when the app becomes active again.
//
//  Architecture rationale: same-window subview (not a separate UIWindow)
//  because UIVisualEffectView blur only renders content from its host
//  window. See Apple UIKit docs and tasks/lessons.md.
//

import UIKit

@MainActor
final class PrivacyOverlayManager {

    static let shared = PrivacyOverlayManager(notificationCenter: .default)

    private(set) var isOverlayVisible = false

    private let notificationCenter: NotificationCenter
    private var hasStarted = false
    private weak var hostWindow: UIWindow?
    private var blurView: UIVisualEffectView?

    // Test-only factory. The state machine in this class is global by
    // intent, so unit tests construct fresh instances with an isolated
    // NotificationCenter to avoid bleeding observer state between tests.
    static func testInstance(
        notificationCenter: NotificationCenter = NotificationCenter()
    ) -> PrivacyOverlayManager {
        PrivacyOverlayManager(notificationCenter: notificationCenter)
    }

    private init(notificationCenter: NotificationCenter) {
        self.notificationCenter = notificationCenter
    }

    deinit {
        notificationCenter.removeObserver(self)
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        notificationCenter.addObserver(
            self,
            selector: #selector(handleWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(handleDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func handleWillResignActive() {
        show()
    }

    @objc private func handleDidBecomeActive() {
        hide()
    }

    func show() {
        guard !isOverlayVisible else { return }
        isOverlayVisible = true
        attachBlurView()
    }

    func hide() {
        guard isOverlayVisible else { return }
        isOverlayVisible = false
        detachBlurView()
    }

    private func attachBlurView() {
        guard blurView == nil else { return }
        guard let window = activeKeyWindow() else { return }

        let effect = UIBlurEffect(style: .systemUltraThinMaterial)
        let view = UIVisualEffectView(effect: effect)
        view.frame = window.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(view)
        window.bringSubviewToFront(view)

        hostWindow = window
        blurView = view
    }

    private func detachBlurView() {
        blurView?.removeFromSuperview()
        blurView = nil
        hostWindow = nil
    }

    private func activeKeyWindow() -> UIWindow? {
        // Single-scene iPhone app today. If multi-scene support lands,
        // route per-scene via UISceneDelegate instead.
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let activeScene = scenes.first { $0.activationState == .foregroundActive }
            ?? scenes.first
        return activeScene?.keyWindow ?? activeScene?.windows.first
    }
}
