//
//  DeepLinkRouter.swift
//  KeepInTouch
//

import Foundation

@MainActor
final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()

    enum Destination: Equatable {
        case person(UUID)
        case home
    }

    @Published var pending: Destination?
    @Published var selectedTab: Int = 0

    /// Parse notification userInfo and set the pending destination.
    nonisolated func handleNotification(userInfo: [AnyHashable: Any]) {
        let type = userInfo["type"] as? String
        if type == "person",
           let idString = userInfo["personId"] as? String,
           let id = UUID(uuidString: idString) {
            Task { @MainActor in self.pending = .person(id) }
        } else if type == "home" {
            Task { @MainActor in self.pending = .home }
        }
    }
}
