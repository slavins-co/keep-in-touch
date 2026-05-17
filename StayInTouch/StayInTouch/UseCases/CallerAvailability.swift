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

/// Production implementation. FaceTime ships on every iPhone, so we
/// surface it unconditionally on iOS. The previous `canOpenURL("facetime://")`
/// gate returned false on simulators (the FaceTime app isn't installed there)
/// which broke testing without buying any safety on real devices — if an
/// edge-case device doesn't have FaceTime, the existing "couldn't open
/// FaceTime" toast in `PersonDetailView.faceTime()` handles it.
struct SystemCallerAvailability: CallerAvailabilityChecking {
    var isFaceTimeAvailable: Bool {
        #if canImport(UIKit)
        return true
        #else
        return false
        #endif
    }
}
