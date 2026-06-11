//
//  ContactStatus.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

enum ContactStatus: String, CaseIterable, Codable, Sendable {
    case onTrack
    case dueSoon
    case overdue
    case unknown
}
