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
    @State private var tutorialCompleted: Bool = true
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
            loadTheme()
            loadTutorialState()
            // v1: stamps lastSeenAppVersion. Future versions present cards.
            _ = WhatsNewService.contentToPresent(repository: dependencies.settingsRepository)
        }
        .onReceive(NotificationCenter.default.publisher(for: .settingsDidChange)) { _ in
            loadTheme()
            loadTutorialState()
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

    private func loadTutorialState() {
        tutorialCompleted = dependencies.settingsRepository.fetch()?.tutorialCompleted ?? true
    }

    private func loadTheme() {
        let theme = dependencies.settingsRepository.fetch()?.theme ?? .system

        switch theme {
        case .dark:
            preferredScheme = .dark
        case .light:
            preferredScheme = .light
        case .system:
            preferredScheme = nil // nil = follow system preference
        }
    }
}

#Preview {
    ContentView()
}
