//
//  ExportFormat.swift
//  KeepInTouch
//

import Foundation

enum ExportFormat: String, CaseIterable {
    case json
    case csv

    var displayName: String {
        switch self {
        case .json: "JSON (backup & re-import)"
        case .csv: "CSV (spreadsheets)"
        }
    }
}
