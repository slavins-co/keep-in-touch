//
//  SwipeDemoView.swift
//  KeepInTouch
//
//  Animated faux contact row that demonstrates the swipe-to-log gesture used
//  on the Home screen. Pure visual: no gesture handling, no real data.
//

import SwiftUI

struct SwipeDemoView: View {
    @State private var offset: CGFloat = 0
    @State private var showCheck: Bool = false

    private let cycle: TimeInterval = 2.4

    var body: some View {
        ZStack(alignment: .trailing) {
            // Hidden swipe action (revealed when offset is negative).
            HStack {
                Spacer()
                ZStack {
                    Rectangle()
                        .fill(DS.Colors.statusAllGood)
                    Image(systemName: showCheck ? "checkmark.circle.fill" : "checkmark")
                        .foregroundStyle(.white)
                        .font(.title3.weight(.bold))
                }
                .frame(width: 88)
            }
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))

            // The "row" itself, offset to reveal the action.
            HStack(spacing: DS.Spacing.md) {
                Circle()
                    .fill(Color(hex: "6BCB77"))
                    .frame(width: 36, height: 36)
                    .overlay(Text("JD").font(.caption.weight(.bold)).foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Jamie Doe")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.Colors.primaryText)
                    Text("Last touch: 9 days ago")
                        .font(.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Colors.pageBg)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .offset(x: offset)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Colors.separator, lineWidth: 0.5)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Swipe demo")
        .accessibilityHint("Animation shows swiping a contact left to log a touch")
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        // One animation cycle: rest -> swipe out -> checkmark fills -> rest.
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(0.3 * 1_000_000_000))
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.45)) { offset = -88 }
                }
                try? await Task.sleep(nanoseconds: UInt64(0.55 * 1_000_000_000))
                await MainActor.run { showCheck = true }
                try? await Task.sleep(nanoseconds: UInt64(0.55 * 1_000_000_000))
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.45)) { offset = 0 }
                    showCheck = false
                }
                try? await Task.sleep(nanoseconds: UInt64((cycle - 1.85) * 1_000_000_000))
            }
        }
    }
}
