//
//  PaywallView.swift
//  KeepInTouch
//
//  The single Pro upgrade screen (#351). Presented from every gated feature via
//  `PaywallTrigger` so the unlock experience is identical everywhere. Reads the
//  shared `PurchaseManager` from the environment; dismisses itself once Pro is
//  unlocked.
//

import SwiftUI

/// Identifies a paywall presentation and carries the analytics source. Use with
/// `.sheet(item:)` so presentation can't get stuck on a stale boolean.
struct PaywallTrigger: Identifiable, Equatable {
    let id = UUID()
    /// Analytics source, e.g. "settings_upgrade", "cap_settings", "feature_stats".
    let source: String
}

struct PaywallView: View {
    let source: String

    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    private let features: [(icon: String, text: String)] = [
        ("infinity", "Unlimited people"),
        ("chart.bar.fill", "Stats & insights"),
        ("square.and.arrow.down", "Import from a backup file"),
        ("person.2.fill", "Group logging — log a whole hangout at once"),
        ("slider.horizontal.3", "Unlimited custom frequencies"),
        ("calendar", "Custom due dates"),
        ("pause.circle", "Pause people"),
        ("rectangle.3.group.fill", "The full widget family"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    header
                    featureList
                    Spacer(minLength: DS.Spacing.md)
                    footer
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.xl)
            }
            .background(DS.Colors.pageBg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        AnalyticsService.track("pro.paywall_dismissed", parameters: ["source": source])
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(DS.Colors.secondaryText)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        .onAppear {
            AnalyticsService.track("pro.paywall_shown", parameters: ["source": source])
        }
        .onChange(of: purchaseManager.isPro) { _, isPro in
            // Unlocked (purchased or restored) — close the paywall.
            if isPro { dismiss() }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(DS.Colors.accent)
                .padding(.top, DS.Spacing.lg)

            Text("A dozen friends, free.\nGot more people who matter?")
                .font(DS.Typography.heroTitle)
                .foregroundStyle(DS.Colors.primaryText)
                .multilineTextAlignment(.center)

            Text("Unlock unlimited people, plus stats, import, group logging, custom frequencies, and the full widget family. Pay once. It's yours forever.")
                .font(DS.Typography.notesBody)
                .foregroundStyle(DS.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            ForEach(features, id: \.text) { feature in
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: feature.icon)
                        .font(.body)
                        .foregroundStyle(DS.Colors.accent)
                        .frame(width: 28)
                    Text(feature.text)
                        .font(DS.Typography.notesBody)
                        .foregroundStyle(DS.Colors.primaryText)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: DS.Spacing.md) {
            if let message = purchaseManager.statusMessage {
                Text(message)
                    .font(DS.Typography.metadata)
                    .foregroundStyle(DS.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }

            if purchaseManager.proProduct != nil {
                Text("Introductory launch price")
                    .font(DS.Typography.metadata)
                    .foregroundStyle(DS.Colors.accent)
            }

            unlockButton

            Button {
                Task { await purchaseManager.restore() }
            } label: {
                Text("Restore Purchases")
                    .font(DS.Typography.notesBody)
                    .foregroundStyle(DS.Colors.accent)
            }
            .disabled(purchaseManager.isProcessing)

            Text("No ads, no account, no cloud. The alternative to charging you is selling you, and I won't.")
                .font(DS.Typography.metadata)
                .foregroundStyle(DS.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.top, DS.Spacing.sm)
        }
    }

    @ViewBuilder
    private var unlockButton: some View {
        if let product = purchaseManager.proProduct {
            Button {
                Task { await purchaseManager.purchase() }
            } label: {
                if purchaseManager.isProcessing {
                    ProgressView().tint(.white)
                } else {
                    Text("Unlock Pro — \(product.displayPrice)")
                }
            }
            .buttonStyle(OnboardingPrimaryButtonStyle())
            .disabled(purchaseManager.isProcessing)
        } else {
            // Product not loaded (offline, or ASC/StoreKit config not ready).
            Button {
                Task { await purchaseManager.loadProductAndRefresh() }
            } label: {
                if purchaseManager.isProcessing {
                    ProgressView().tint(.white)
                } else {
                    Text("Couldn't load — Retry")
                }
            }
            .buttonStyle(OnboardingPrimaryButtonStyle())
            .disabled(purchaseManager.isProcessing)
        }
    }
}
