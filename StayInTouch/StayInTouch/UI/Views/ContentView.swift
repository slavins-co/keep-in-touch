//
//  ContentView.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @State private var preferredScheme: ColorScheme? = nil
    @State private var tutorialCompleted: Bool = false
    @Environment(\.dependencies) private var dependencies

    var body: some View {
        SwiftUI.Group {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.isOnboardingCompleted {
                mainTabRoot
                    .transition(.opacity)
            } else {
                OnboardingFlowView(viewModel: viewModel)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: viewModel.isOnboardingCompleted)
        .animation(.easeInOut(duration: 0.3), value: tutorialCompleted)
        .onAppear {
            viewModel.start()
            loadSettings()
            // v1: stamps lastSeenAppVersion. Future versions present cards.
            _ = WhatsNewService.contentToPresent(repository: dependencies.settingsRepository)
        }
        .onReceive(NotificationCenter.default.publisher(for: .settingsDidChange)) { _ in
            loadSettings()
        }
        .preferredColorScheme(preferredScheme)
        .errorToast()
    }

    @ViewBuilder
    private var mainTabRoot: some View {
        if tutorialCompleted {
            MainTabView()
        } else {
            WalkthroughHost(settingsRepository: dependencies.settingsRepository) {
                MainTabView()
            }
        }
    }

    /// Single Core Data fetch consumed by every setting-derived view state:
    /// theme, tutorialCompleted flag, and the TipKit gate. Two fetches per
    /// `.settingsDidChange` notification was wasteful.
    private func loadSettings() {
        let settings = dependencies.settingsRepository.fetch()
        tutorialCompleted = settings?.tutorialCompleted ?? false
        TutorialTipGate.update(walkthroughCompleted: tutorialCompleted)

        switch settings?.theme ?? .system {
        case .dark:   preferredScheme = .dark
        case .light:  preferredScheme = .light
        case .system: preferredScheme = nil
        }
    }
}

#Preview {
    ContentView()
}
