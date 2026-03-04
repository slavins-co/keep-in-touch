//
//  MainTabView.swift
//  KeepInTouch
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject private var deepLinkRouter = DeepLinkRouter.shared

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $deepLinkRouter.selectedTab) {
            HomeView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: deepLinkRouter.selectedTab == 0 ? "house.fill" : "house")
                    Text("Home")
                }
                .tag(0)

            ContactsListView(viewModel: viewModel)
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
    }
}
