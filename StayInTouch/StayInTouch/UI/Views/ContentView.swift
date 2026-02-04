//
//  ContentView.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @State private var preferredScheme: ColorScheme? = nil

    var body: some View {
        SwiftUI.Group {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.isOnboardingCompleted {
                HomeView()
            } else {
                OnboardingFlowView(viewModel: viewModel)
            }
        }
        .onAppear {
            viewModel.start()
            loadTheme()
        }
        .onReceive(NotificationCenter.default.publisher(for: .settingsDidChange)) { _ in
            loadTheme()
        }
        .preferredColorScheme(preferredScheme)
    }

    private func loadTheme() {
        let repo = CoreDataAppSettingsRepository(context: CoreDataStack.shared.viewContext)
        let theme = repo.fetch()?.theme ?? .light
        preferredScheme = theme == .dark ? .dark : .light
    }
}

#Preview {
    ContentView()
}
