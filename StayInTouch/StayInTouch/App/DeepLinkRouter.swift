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
        let type = userInfo[NotificationIdentifier.UserInfoKey.type.rawValue] as? String
        if type == NotificationIdentifier.UserInfoValue.person.rawValue,
           let idString = userInfo[NotificationIdentifier.UserInfoKey.personId.rawValue] as? String,
           let id = UUID(uuidString: idString) {
            Task { @MainActor in self.pending = .person(id) }
        } else if type == NotificationIdentifier.UserInfoValue.home.rawValue {
            Task { @MainActor in self.pending = .home }
        }
    }

    /// Translate a `keepintouch://` URL (from a widget tap) into a pending
    /// destination. Unknown or malformed URLs are silently ignored.
    @discardableResult
    func handleURL(_ url: URL) -> Bool {
        guard let route = DeepLinkRoute(url: url) else { return false }
        switch route {
        case .overdue:
            pending = .home
        case .person(let id):
            pending = .person(id)
        }
        return true
    }
}
