//
//  Group.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

struct Group: Identifiable, Equatable {
    let id: UUID
    var name: String
    var frequencyDays: Int
    var warningDays: Int
    var colorHex: String?
    var isDefault: Bool
    var sortOrder: Int
    var createdAt: Date
    var modifiedAt: Date
}
