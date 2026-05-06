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

    enum RingColor: Equatable {
        case overdue
        case dueSoon
    }

    enum CircularRing: Equatable {
        /// No ring drawn. Symbol-only state (all caught up or no tracked people).
        case empty
        /// Single full ring in one color (only one at-risk bucket has people).
        case binary(color: RingColor)
        /// Split ring: red arc covers `overdueFraction` (0...1) of the
        /// circumference; orange arc covers the remainder. Used when both
        /// overdue and due-soon buckets are non-empty.
        case twoTone(overdueFraction: Double)
    }

    /// Decide what kind of ring (if any) the accessory circular widget should draw.
    /// `hasTrackedPeople` is accepted for symmetry with the other helpers; the
    /// count fields already encode the at-risk state, so it isn't consulted here.
    static func ring(
        overdueCount: Int,
        dueSoonCount: Int,
        hasTrackedPeople: Bool
    ) -> CircularRing {
        _ = hasTrackedPeople
        if overdueCount == 0 && dueSoonCount == 0 {
            return .empty
        }
        if overdueCount > 0 && dueSoonCount == 0 {
            return .binary(color: .overdue)
        }
        if overdueCount == 0 && dueSoonCount > 0 {
            return .binary(color: .dueSoon)
        }
        let total = Double(overdueCount + dueSoonCount)
        let fraction = Double(overdueCount) / total
        return .twoTone(overdueFraction: fraction)
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
