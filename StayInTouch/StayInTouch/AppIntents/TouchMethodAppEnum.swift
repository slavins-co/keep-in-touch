//
//  TouchMethodAppEnum.swift
//  KeepInTouch
//
//  AppEnum conformance for the existing TouchMethod value type so it
//  appears as a typed picker in the Shortcuts editor and Siri.
//

import AppIntents

extension TouchMethod: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Connection Method")
    }

    static var caseDisplayRepresentations: [TouchMethod: DisplayRepresentation] {
        [
            .text: DisplayRepresentation(title: "Text"),
            .call: DisplayRepresentation(title: "Call"),
            .irl: DisplayRepresentation(title: "In Person"),
            .email: DisplayRepresentation(title: "Email"),
            .facetime: DisplayRepresentation(title: "FaceTime"),
            .other: DisplayRepresentation(title: "Other"),
        ]
    }

    /// Verb form used in user-facing dialog ("Logged a call with Mom").
    /// Lives next to the AppEnum case mapping so any Siri / Shortcuts /
    /// dialog phrasing has a single source of truth.
    var verb: String {
        switch self {
        case .text: return "text"
        case .call: return "call"
        case .irl: return "visit"
        case .email: return "email"
        case .facetime: return "FaceTime"
        case .other: return "touch"
        }
    }
}
