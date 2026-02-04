//
//  Tag.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

struct Tag: Identifiable, Equatable {
    let id: UUID
    var name: String
    var colorHex: String
    var sortOrder: Int
    var createdAt: Date
    var modifiedAt: Date
}
