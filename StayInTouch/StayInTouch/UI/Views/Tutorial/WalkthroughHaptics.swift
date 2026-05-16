//
//  WalkthroughHaptics.swift
//  KeepInTouch
//
//  Tiny haptics seam so the walkthrough coordinator stays testable
//  without firing real device haptics in unit tests.
//

import UIKit

protocol WalkthroughHaptics {
    func soft()
}

struct DefaultWalkthroughHaptics: WalkthroughHaptics {
    func soft() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
    }
}

struct NoOpWalkthroughHaptics: WalkthroughHaptics {
    func soft() {}
}
