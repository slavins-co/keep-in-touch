//
//  PersonDetailModal.swift
//  KeepInTouch
//

import Foundation

// MARK: - Sheet presentations

enum PersonDetailSheet: Identifiable {
    case logTouch
    case editTouch(TouchEvent)
    case changeCadence
    case manageGroups
    case resumeDatePicker
    case reminderTimePicker
    case snoozeDatePicker
    case customDueDatePicker
    case birthdayEditor

    var id: String {
        switch self {
        case .logTouch: return "logTouch"
        case .editTouch(let t): return "editTouch-\(t.id)"
        case .changeCadence: return "changeCadence"
        case .manageGroups: return "manageGroups"
        case .resumeDatePicker: return "resumeDatePicker"
        case .reminderTimePicker: return "reminderTimePicker"
        case .snoozeDatePicker: return "snoozeDatePicker"
        case .customDueDatePicker: return "customDueDatePicker"
        case .birthdayEditor: return "birthdayEditor"
        }
    }
}

// MARK: - Alert presentations

enum PersonDetailAlert: Identifiable {
    case resumePrompt
    case deleteConfirm(TouchEvent)
    case removeConfirm

    var id: String {
        switch self {
        case .resumePrompt: return "resumePrompt"
        case .deleteConfirm(let t): return "deleteConfirm-\(t.id)"
        case .removeConfirm: return "removeConfirm"
        }
    }
}

// MARK: - Settings actions

enum PersonSettingsAction {
    case changeCadence
    case manageGroups
    case resumePrompt
    case removeConfirm
    case reminderTimePicker
    case snoozeDatePicker(initialDate: Date)
    case customDueDatePicker(initialDate: Date)
    case birthdayEditor
}
