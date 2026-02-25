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
