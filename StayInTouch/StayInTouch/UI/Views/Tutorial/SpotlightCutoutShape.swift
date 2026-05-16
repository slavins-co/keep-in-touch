//
//  SpotlightCutoutShape.swift
//  KeepInTouch
//
//  A Shape that draws a full-bounds rectangle with a rounded-rect cutout,
//  used with eoFill to render a dim overlay that "spotlights" a UI element.
//

import SwiftUI

struct SpotlightCutoutShape: Shape {
    /// The rectangle (in this shape's local coordinate space) to cut out.
    /// Use .zero / .null for a fully-dimmed overlay with no spotlight.
    var cutoutRect: CGRect
    var cornerRadius: CGFloat = 12
    var padding: CGFloat = 8

    var animatableData: AnimatablePair<
        AnimatablePair<CGFloat, CGFloat>,
        AnimatablePair<CGFloat, CGFloat>
    > {
        get {
            AnimatablePair(
                AnimatablePair(cutoutRect.origin.x, cutoutRect.origin.y),
                AnimatablePair(cutoutRect.size.width, cutoutRect.size.height)
            )
        }
        set {
            cutoutRect = CGRect(
                x: newValue.first.first,
                y: newValue.first.second,
                width: newValue.second.first,
                height: newValue.second.second
            )
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        guard !cutoutRect.isEmpty, !cutoutRect.isNull else { return path }
        let padded = cutoutRect.insetBy(dx: -padding, dy: -padding)
        path.addRoundedRect(in: padded, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        return path
    }
}
