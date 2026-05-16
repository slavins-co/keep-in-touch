//
//  AllCaughtUpTip.swift
//  KeepInTouch
//
//  TipKit hint anchored to the "all caught up" banner on Home.
//

import TipKit

struct AllCaughtUpTip: Tip {
    @Parameter static var walkthroughCompleted: Bool = false

    var title: Text { Text("Nicely done") }
    var message: Text? {
        Text("Your cadence can be tuned in Settings if this feels too loose or tight.")
    }
    var image: Image? { Image(systemName: "checkmark.seal.fill") }

    var rules: [Rule] {
        #Rule(Self.$walkthroughCompleted) { $0 }
    }
}
