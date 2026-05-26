//
//  TouchMethod.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

enum TouchMethod: String, CaseIterable, Codable, Sendable {
    case text = "Text"
    case call = "Call"
    case irl = "IRL"
    case email = "Email"
    case facetime = "FaceTime"
    case other = "Other"
}
