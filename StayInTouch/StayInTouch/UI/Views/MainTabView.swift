//
//  MainTabView.swift
//  KeepInTouch
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject private var deepLinkRouter = DeepLinkRouter.shared
    @State private var selectedPerson: Person?
    @State private var freshStartReason: FreshStartDetector.Reason?

    var body: some View {
        TabView(selection: $deepLinkRouter.selectedTab) {
            HomeView(viewModel: viewModel, selectPerson: { selectedPerson = $0 })
                .tabItem {
                    Image(systemName: deepLinkRouter.selectedTab == 0 ? "house.fill" : "house")
                    Text("Home")
                }
                .tag(0)
                .accessibilityLabel("Home tab")

            ContactsListView(viewModel: viewModel, selectPerson: { selectedPerson = $0 })
                .tabItem {
                    Image(systemName: deepLinkRouter.selectedTab == 1 ? "person.2.fill" : "person.2")
                    Text("Contacts")
                }
                .tag(1)
                .accessibilityLabel("Contacts tab")

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Image(systemName: deepLinkRouter.selectedTab == 2 ? "gearshape.fill" : "gearshape")
                Text("Settings")
            }
            .tag(2)
            .accessibilityLabel("Settings tab")
        }
        .toolbarBackground(.visible, for: .tabBar)
        .tint(DS.Colors.accent)
        .overlay {
            // Dimming lives here so it fades in place instead of
            // sliding with the fullScreenCover transition.
            if selectedPerson != nil {
                DS.Colors.sheetOverlay
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: selectedPerson != nil)
        .fullScreenCover(item: $selectedPerson) { person in
            DismissableFullScreenCover {
                PersonDetailView(person: person)
            }
        }
        .onChange(of: deepLinkRouter.pending) { _, newValue in
            if newValue != nil { processPendingDeepLink() }
        }
        .onAppear {
            processPendingDeepLink()
        }
        .onChange(of: viewModel.freshStartReason) { _, newValue in
            if newValue != nil && selectedPerson == nil {
                freshStartReason = newValue
            }
        }
        .fullScreenCover(item: $freshStartReason) { reason in
            FreshStartPromptView(
                reason: reason,
                onFreshStart: {
                    await viewModel.executeFreshStart()
                    freshStartReason = nil
                },
                onDismiss: {
                    viewModel.dismissFreshStartPrompt()
                    freshStartReason = nil
                }
            )
        }
    }

    // MARK: - Deep Link Processing

    private func processPendingDeepLink() {
        guard let destination = deepLinkRouter.pending else { return }
        deepLinkRouter.pending = nil

        switch destination {
        case .person(let id):
            deepLinkRouter.selectedTab = 0
            if let person = CoreDataPersonRepository(context: CoreDataStack.shared.viewContext).fetch(id: id) {
                selectedPerson = person
            }
        case .home:
            deepLinkRouter.selectedTab = 0
            viewModel.selectedGroupId = nil
            viewModel.selectedTagId = nil
            viewModel.applyFilters()
        }
    }
}
