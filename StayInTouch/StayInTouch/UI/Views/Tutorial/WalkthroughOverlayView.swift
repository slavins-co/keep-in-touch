//
//  WalkthroughOverlayView.swift
//  KeepInTouch
//
//  Top-level overlay that renders the dim, the spotlight cutout around the
//  current step's anchor, and the step card. Designed to be mounted via
//  `.overlayPreferenceValue(TutorialAnchorKey.self) { ... }` so it can read
//  anchor bounds advertised by descendant views.
//

import SwiftUI

struct WalkthroughOverlayView: View {
    @ObservedObject var coordinator: WalkthroughCoordinator
    let anchors: [String: Anchor<CGRect>]

    /// Approximate half-height used to position the step card adjacent to its
    /// anchor. Errors here are absorbed by the surrounding ZStack — exact pixel
    /// alignment isn't required.
    private let cardHalfHeight: CGFloat = 110

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let step = coordinator.currentStep {
                    overlayContent(step: step, geo: geo)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.3), value: coordinator.currentStep)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(named: Text("Continue")) { coordinator.advance() }
            .accessibilityAction(named: Text("Skip tutorial")) { coordinator.skip() }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func overlayContent(step: WalkthroughStep, geo: GeometryProxy) -> some View {
        let resolved = resolveAnchor(for: step, in: geo)

        // Dim with cutout.
        SpotlightCutoutShape(cutoutRect: resolved ?? .zero)
            .fill(DS.Colors.sheetOverlay, style: FillStyle(eoFill: true))
            .contentShape(Rectangle())
            .onTapGesture { /* swallow taps on dim */ }

        // Step card.
        let cardPoint = cardPosition(for: resolved, in: geo)
        WalkthroughStepCard(
            step: step,
            onPrimary: coordinator.advance,
            onSkip: coordinator.skip
        )
        .position(cardPoint)
    }

    private func resolveAnchor(for step: WalkthroughStep, in geo: GeometryProxy) -> CGRect? {
        guard let id = step.anchorID, let anchor = anchors[id] else { return nil }
        let rect = geo[anchor]
        return (rect.isEmpty || rect.isNull) ? nil : rect
    }

    private func cardPosition(for anchorRect: CGRect?, in geo: GeometryProxy) -> CGPoint {
        guard let rect = anchorRect else {
            // Centered card.
            return CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        let spaceBelow = geo.size.height - rect.maxY
        let spaceAbove = rect.minY
        let preferBelow = spaceBelow >= spaceAbove
        let y: CGFloat = preferBelow
            ? min(geo.size.height - cardHalfHeight - DS.Spacing.lg, rect.maxY + DS.Spacing.md + cardHalfHeight)
            : max(cardHalfHeight + DS.Spacing.lg, rect.minY - DS.Spacing.md - cardHalfHeight)
        return CGPoint(x: geo.size.width / 2, y: y)
    }
}
