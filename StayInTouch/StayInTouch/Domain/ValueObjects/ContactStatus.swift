//
//  ContactStatus.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

enum ContactStatus: String, CaseIterable, Codable {
    case onTrack
    case dueSoon
    case overdue
    case unknown
}
