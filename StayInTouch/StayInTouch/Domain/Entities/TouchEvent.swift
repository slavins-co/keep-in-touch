//
//  TouchEvent.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

struct TouchEvent: Identifiable, Equatable {
    let id: UUID
    var personId: UUID
    var at: Date
    var method: TouchMethod
    var notes: String?
    var timeOfDay: TimeOfDay?
    var createdAt: Date
    var modifiedAt: Date
}
