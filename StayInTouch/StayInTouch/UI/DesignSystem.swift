//
//  DesignSystem.swift
//  StayInTouch
//
//  Design system foundation for the UX redesign (Issue #24).
//  All views reference DS tokens instead of hardcoding values.
//

import SwiftUI

// MARK: - Design System Namespace

enum DS {

    // MARK: - Colors

    enum Colors {
        // Backgrounds
        static let background = Color(.systemBackground)
        static let secondaryBackground = Color(.secondarySystemBackground)
        static let groupedBackground = Color(.systemGroupedBackground)

        // Text
        static let primaryText = Color(.label)
        static let secondaryText = Color(.secondaryLabel)
        static let tertiaryText = Color(.tertiaryLabel)

        // Status
        static let statusOverdue = Color(hex: "FF3B30")
        static let statusDueSoon = Color(hex: "FF9500")
        static let statusAllGood = Color(hex: "34C759")
        static let statusUnknown = Color(hex: "8E8E93")

        // Accent & Actions
        static let accent = Color.accentColor
        static let destructive = Color.red
        static let muted = Color(.systemGray4)

        // Dividers
        static let separator = Color(.separator)

        static func statusColor(for status: ContactStatus) -> Color {
            switch status {
            case .overdue: return statusOverdue
            case .dueSoon: return statusDueSoon
            case .onTrack: return statusAllGood
            case .unknown: return statusUnknown
            }
        }

        static func statusHex(for status: ContactStatus) -> String {
            switch status {
            case .overdue: return "FF3B30"
            case .dueSoon: return "FF9500"
            case .onTrack: return "34C759"
            case .unknown: return "8E8E93"
            }
        }
    }

    // MARK: - Typography

    enum Typography {
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let heroTitle = Font.title.weight(.bold)
        static let title = Font.title2.weight(.semibold)
        static let sectionHeader = Font.subheadline.weight(.bold)
        static let contactName = Font.body.weight(.medium)
        static let metadata = Font.subheadline
        static let caption = Font.caption
        static let captionBold = Font.caption.weight(.medium)
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    // MARK: - Corner Radius

    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 16
    }

    // MARK: - Touch Method Icons

    static func touchMethodIcon(_ method: TouchMethod) -> String {
        switch method {
        case .text: return "message.fill"
        case .call: return "phone.fill"
        case .irl: return "person.2.fill"
        case .email: return "envelope.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Reusable Components

struct SubtleDivider: View {
    var body: some View {
        Rectangle()
            .fill(DS.Colors.separator)
            .frame(height: 0.5)
    }
}

struct StatusIndicator: View {
    let status: ContactStatus
    var daysOverdue: Int = 0

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            if daysOverdue > 0 {
                Text("+\(daysOverdue)d")
                    .font(DS.Typography.captionBold)
                    .foregroundStyle(DS.Colors.statusOverdue)
            }
            Circle()
                .fill(DS.Colors.statusColor(for: status))
                .frame(width: 7, height: 7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(statusAccessibilityLabel)
    }

    private var statusAccessibilityLabel: String {
        switch status {
        case .overdue:
            return daysOverdue > 0 ? "\(daysOverdue) days overdue" : "overdue"
        case .dueSoon:
            return "due soon"
        case .onTrack:
            return "on track"
        case .unknown:
            return "no contact yet"
        }
    }
}

struct TagPill: View {
    let name: String
    let colorHex: String

    init(tag: Tag) {
        self.name = tag.name
        self.colorHex = tag.colorHex
    }

    init(name: String, colorHex: String) {
        self.name = name
        self.colorHex = colorHex
    }

    var body: some View {
        Text(name)
            .font(DS.Typography.caption)
            .foregroundStyle(Color(hex: colorHex))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(hex: colorHex).opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        for (index, row) in rows.enumerated() {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            height += rowHeight
            if index < rows.count - 1 { height += spacing }
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            var x = bounds.minX
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y + (rowHeight - size.height) / 2), proposal: .unspecified)
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubview]] = [[]]
        var currentWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentWidth + size.width > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                currentWidth = 0
            }
            rows[rows.count - 1].append(subview)
            currentWidth += size.width + spacing
        }
        return rows
    }
}

// MARK: - View Modifiers

struct FlatSectionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, DS.Spacing.md)
    }
}

extension View {
    func flatSection() -> some View {
        modifier(FlatSectionModifier())
    }
}
