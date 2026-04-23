//
//  DeepLinkRoute.swift
//  KeepInTouch
//
//  Pure URL contract shared between the app and the widget extension.
//  The widget builds URLs with `url(for:)`; the app parses them with
//  `init?(url:)` and forwards to `DeepLinkRouter`.
//

import Foundation

enum DeepLinkRoute: Equatable {
    case overdue
    case person(UUID)

    static let scheme = "keepintouch"

    init?(url: URL) {
        guard url.scheme == Self.scheme else { return nil }

        let pathParts = url.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        let host = url.host
        let segments = host.map { [$0] + pathParts } ?? pathParts

        switch segments.first {
        case "overdue" where segments.count == 1:
            self = .overdue
        case "person" where segments.count == 2:
            guard let id = UUID(uuidString: segments[1]) else { return nil }
            self = .person(id)
        default:
            return nil
        }
    }

    func url() -> URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        switch self {
        case .overdue:
            components.host = "overdue"
        case .person(let id):
            components.host = "person"
            components.path = "/\(id.uuidString)"
        }
        // Safe: scheme + host (+ optional path) are always set above, so
        // URLComponents can always produce a valid URL here.
        return components.url!
    }
}
