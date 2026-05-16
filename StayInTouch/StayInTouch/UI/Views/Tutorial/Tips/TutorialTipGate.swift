//
//  TutorialTipGate.swift
//  KeepInTouch
//
//  Centralised toggle that flips the TipKit parameters on every tutorial
//  tip in one call. Updated at app launch from AppSettings and again
//  whenever the WalkthroughCoordinator finishes (or is reset via the
//  "Replay tutorial" Settings row).
//

import Foundation

enum TutorialTipGate {
    /// Sync TipKit parameters from the current persisted walkthrough state.
    /// Pass `true` after the walkthrough completes; pass `false` to suppress
    /// tips again (e.g. when "Replay tutorial" is invoked).
    static func update(walkthroughCompleted: Bool) {
        LogTouchSwipeTip.walkthroughCompleted = walkthroughCompleted
        AllCaughtUpTip.walkthroughCompleted = walkthroughCompleted
        TagsDiscoveryTip.walkthroughCompleted = walkthroughCompleted
    }
}
