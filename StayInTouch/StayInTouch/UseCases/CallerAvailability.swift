//
//  CallerAvailability.swift
//  KeepInTouch
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Reports which call channels are reachable from the device. Currently scoped
/// to FaceTime only — phone is assumed always-available on any iPhone where
/// the Call button is enabled. Abstracted so ViewModels stay UIKit-free.
protocol CallerAvailabilityChecking {
    var isFaceTimeAvailable: Bool { get }
}

/// Production implementation backed by `UIApplication.canOpenURL("facetime://")`.
/// On iPhone where FaceTime is preinstalled this returns true. The check
/// requires `facetime` in `LSApplicationQueriesSchemes`.
struct SystemCallerAvailability: CallerAvailabilityChecking {
    var isFaceTimeAvailable: Bool {
        #if canImport(UIKit)
        guard let url = URL(string: "facetime://") else { return false }
        return UIApplication.shared.canOpenURL(url)
        #else
        return false
        #endif
    }
}
