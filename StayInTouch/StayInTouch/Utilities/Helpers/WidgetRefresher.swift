//
//  WidgetRefresher.swift
//  KeepInTouch
//
//  Single app-side boundary that reloads all widget timelines after a
//  Core Data mutation the widget might care about. iOS coalesces rapid
//  successive reloads, so we don't debounce here.
//

import Foundation
import WidgetKit

enum WidgetRefresher {
    static func reloadAllTimelines() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
