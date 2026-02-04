//
//  SLAStatus.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

enum SLAStatus: String, CaseIterable, Codable {
    case inSLA
    case dueSoon
    case outOfSLA
    case unknown
}
