//
//  AccessoryWidgetLogic.swift
//  KeepInTouch (Shared — compiled into main app + widget extension)
//
//  Pure layout/copy decisions for the Lock Screen and StandBy accessory
//  widgets. Extracted so the SwiftUI views stay thin and the routing
//  rules stay testable without a SwiftUI inspection dependency.
//
//  Issue #279.
//

import Foundation

enum AccessoryWidgetLogic {

    // MARK: - Circular ring fill

    enum CircularRing: Equatable {
        /// No ring drawn. Symbol-only state (all caught up or no tracked people).
        case empty
        /// Gauge fill expressed as fractions of the full circumference.
        /// Both fractions are 0...1 and their sum is ≤ 1.0 (the unfilled
        /// remainder is the on-track portion of the user's tracked set).
        ///
        /// Visual interpretation:
        /// - In fullColor mode: red arc covers `overdueFraction`, orange
        ///   arc continues for `dueSoonFraction`, the rest is unfilled.
        /// - In monochrome / accented mode: a single tinted arc fills
        ///   `overdueFraction + dueSoonFraction` of the circumference,
        ///   giving a "how bad is it" gauge — sliver = healthy, full =
        ///   everyone needs a reach-out.
        case gauge(overdueFraction: Double, dueSoonFraction: Double)
    }

    /// Decide what kind of ring (if any) the accessory circular widget should draw.
    /// The gauge fractions are computed against `trackedCount` so the ring
    /// answers "what fraction of the people I follow need attention?".
    /// `hasTrackedPeople` is accepted for call-site symmetry.
    static func ring(
        overdueCount: Int,
        dueSoonCount: Int,
        trackedCount: Int,
        hasTrackedPeople: Bool
    ) -> CircularRing {
        _ = hasTrackedPeople
        let atRisk = overdueCount + dueSoonCount
        if atRisk == 0 {
            return .empty
        }
        // Defensive: at-risk should be a subset of tracked, but if data
        // is inconsistent fall back to filling the ring proportional to
        // at-risk itself rather than dividing by zero.
        let denom = max(trackedCount, atRisk)
        return .gauge(
            overdueFraction: Double(overdueCount) / Double(denom),
            dueSoonFraction: Double(dueSoonCount) / Double(denom)
        )
    }

    // MARK: - Circular center digit

    /// Total at-risk count to render at the center of the circular widget,
    /// or nil if the widget should fall back to a symbol-only empty state.
    /// Returns `overdue + dueSoon` because the lock-screen / accented
    /// rendering mode strips the two-tone color distinction, so a single
    /// total reads more clearly than a per-bucket count.
    /// `hasTrackedPeople` is accepted for call-site symmetry; the count fields
    /// already encode the empty case.
    static func centerDigit(
        overdueCount: Int,
        dueSoonCount: Int,
        hasTrackedPeople: Bool
    ) -> String? {
        _ = hasTrackedPeople
        let total = overdueCount + dueSoonCount
        return total > 0 ? "\(total)" : nil
    }

    // MARK: - Rectangular subtitle

    /// Composes the second line of the rectangular widget: featured
    /// person's status (delegates to `WidgetPersonStatus.shortSubtitle`)
    /// + optional "X more" suffix.
    static func rectangularSubtitle(
        featuredStatus: WidgetPersonStatus,
        additionalAtRisk: Int
    ) -> String {
        let primary = featuredStatus.shortSubtitle
        if additionalAtRisk > 0 {
            return "\(primary) · \(additionalAtRisk) more"
        }
        return primary
    }

    // MARK: - Inline label

    struct InlineLabel: Equatable {
        let symbol: String
        let text: String
    }

    /// Composes the single-line inline widget label.
    /// Order of preference: featured overdue → featured due-soon →
    /// all-caught-up → no-tracked-people.
    /// Symbol is `person.crop.circle.fill` for any at-risk state — text
    /// carries the urgency. Empty / no-tracked states keep their own symbol.
    static func inlineLabel(snapshot: WidgetDataProvider.Snapshot) -> InlineLabel {
        if let featured = snapshot.featured.first {
            let name = featured.displayShortName
            if snapshot.overdueCount > 0 {
                return InlineLabel(
                    symbol: "person.crop.circle.fill",
                    text: "\(snapshot.overdueCount) overdue · \(name) next"
                )
            }
            if snapshot.dueSoonCount > 0 {
                return InlineLabel(
                    symbol: "person.crop.circle.fill",
                    text: "\(snapshot.dueSoonCount) due soon · \(name) next"
                )
            }
        }
        if snapshot.hasTrackedPeople {
            return InlineLabel(symbol: "hand.wave.fill", text: "All caught up")
        }
        return InlineLabel(symbol: "person.crop.circle.badge.plus", text: "Add someone to track")
    }
}
