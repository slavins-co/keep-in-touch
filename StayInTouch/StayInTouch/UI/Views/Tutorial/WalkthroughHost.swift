//
//  WalkthroughHost.swift
//  KeepInTouch
//
//  Wraps a content view (typically MainTabView) and mounts the tutorial
//  walkthrough overlay above it. The demo PersonDetail (Walkthrough B)
//  is presented in a fullScreenCover with its own nested overlay because
//  `.overlay()` does NOT cover `fullScreenCover` in SwiftUI.
//

import SwiftUI

struct WalkthroughHost<Content: View>: View {
    @StateObject private var coordinator: WalkthroughCoordinator
    private let content: Content

    init(
        settingsRepository: AppSettingsRepository,
        @ViewBuilder content: () -> Content
    ) {
        _coordinator = StateObject(
            wrappedValue: WalkthroughCoordinator(settingsRepository: settingsRepository)
        )
        self.content = content()
    }

    var body: some View {
        content
            .overlayPreferenceValue(TutorialAnchorKey.self) { anchors in
                if coordinator.currentStep?.phase == .homeA {
                    WalkthroughOverlayView(coordinator: coordinator, anchors: anchors)
                }
            }
            .fullScreenCover(isPresented: Binding(
                get: { coordinator.isPresentingDemoDetail },
                set: { newValue in
                    // User-initiated dismiss (drag, swipe) — skip walkthrough.
                    if !newValue && coordinator.isPresentingDemoDetail {
                        coordinator.skip()
                    }
                }
            )) {
                TutorialPersonDetailHost()
                    .overlayPreferenceValue(TutorialAnchorKey.self) { anchors in
                        if coordinator.currentStep?.phase == .detailB {
                            WalkthroughOverlayView(coordinator: coordinator, anchors: anchors)
                        }
                    }
            }
            .onAppear { coordinator.start() }
    }
}
