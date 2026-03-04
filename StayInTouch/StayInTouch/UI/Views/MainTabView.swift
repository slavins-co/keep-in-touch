//
//  MainTabView.swift
//  KeepInTouch
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject private var deepLinkRouter = DeepLinkRouter.shared
    @State private var selectedPerson: Person?

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $deepLinkRouter.selectedTab) {
            HomeView(viewModel: viewModel, selectPerson: { selectedPerson = $0 })
                .tabItem {
                    Image(systemName: deepLinkRouter.selectedTab == 0 ? "house.fill" : "house")
                    Text("Home")
                }
                .tag(0)

            ContactsListView(viewModel: viewModel, selectPerson: { selectedPerson = $0 })
                .tabItem {
                    Image(systemName: deepLinkRouter.selectedTab == 1 ? "person.2.fill" : "person.2")
                    Text("Contacts")
                }
                .tag(1)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Image(systemName: deepLinkRouter.selectedTab == 2 ? "gearshape.fill" : "gearshape")
                Text("Settings")
            }
            .tag(2)
        }
        .tint(DS.Colors.accent)
        .fullScreenCover(item: $selectedPerson) { person in
            DismissableFullScreenCover {
                PersonDetailView(person: person)
            }
            .presentationBackground(.clear)
        }
        .onChange(of: deepLinkRouter.pending) { _, newValue in
            if newValue != nil { processPendingDeepLink() }
        }
        .onAppear {
            processPendingDeepLink()
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
