//
//  TagsDiscoveryTip.swift
//  KeepInTouch
//
//  TipKit hint on the Tags row inside a real PersonDetailView.
//

import TipKit

struct TagsDiscoveryTip: Tip {
    @Parameter static var walkthroughCompleted: Bool = false

    var title: Text { Text("Tags group across cadences") }
    var message: Text? {
        Text("Use them for circles like College or Work — independent of how often you check in.")
    }
    var image: Image? { Image(systemName: "tag.fill") }

    var rules: [Rule] {
        #Rule(Self.$walkthroughCompleted) { $0 }
    }
}
