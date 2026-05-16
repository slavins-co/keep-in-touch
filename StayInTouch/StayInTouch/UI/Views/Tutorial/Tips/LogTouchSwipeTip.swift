//
//  LogTouchSwipeTip.swift
//  KeepInTouch
//
//  TipKit hint that encourages discovery of swipe-to-log after the
//  walkthrough completes.
//

import TipKit

struct LogTouchSwipeTip: Tip {
    @Parameter static var walkthroughCompleted: Bool = false

    var title: Text { Text("Swipe to log") }
    var message: Text? { Text("Quick log without opening their card.") }
    var image: Image? { Image(systemName: "hand.draw.fill") }

    var rules: [Rule] {
        #Rule(Self.$walkthroughCompleted) { $0 }
    }
}
