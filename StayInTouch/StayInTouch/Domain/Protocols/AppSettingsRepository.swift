//
//  AppSettingsRepository.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

protocol AppSettingsRepository {
    func fetch() -> AppSettings?
    func save(_ settings: AppSettings) throws
}
