//
//  WidgetUpsellView.swift
//  KeepInTouchWidget
//
//  Pro-locked placeholder for free users on Pro-only widget surfaces
//  (birthday widgets, lock-screen / StandBy accessories). Renders in place of
//  real content — the widget stays in the gallery so the lock reads as a
//  "Pro feature", matching the in-app gating UX (#351, PR6). Tapping deep-links
//  to the paywall via `DeepLinkRoute.paywall`.
//
//  Container background is supplied by the caller's `.widgetAppTheme(_:)`
//  (system families) or `.containerBackground(.clear, …)` (accessories), so
//  these views set only their own content + `.widgetURL`.
//

import SwiftUI
import WidgetKit

// MARK: - System (small / medium)

struct WidgetProUpsellView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Keep In Touch Pro")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
            Text("Unlock the full widget family")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(DeepLinkRoute.paywall.url())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Keep In Touch Pro. Unlock the full widget family.")
    }
}

// MARK: - Accessory (lock screen / StandBy)

struct AccessoryProUpsellView: View {
    let family: WidgetFamily

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                Image(systemName: "lock.fill")
                    .font(.title3)
            case .accessoryRectangular:
                Label("Unlock with Pro", systemImage: "lock.fill")
                    .font(.headline)
            default:
                // accessoryInline + any future accessory family
                Label("Keep In Touch Pro", systemImage: "lock.fill")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(DeepLinkRoute.paywall.url())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Keep In Touch Pro. Unlock to use this widget.")
    }
}
