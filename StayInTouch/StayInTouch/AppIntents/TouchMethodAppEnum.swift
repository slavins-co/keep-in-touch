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
        TypeDisplayRepresentation(name: "Touch Method")
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
}
