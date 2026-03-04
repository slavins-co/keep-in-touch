//
//  DesignSystem.swift
//  KeepInTouch
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

        // MARK: Adaptive Surfaces (light/dark)

        static let pageBg = adaptive(light: "FFFFFF", dark: "111111")
        static let surfaceElevated = adaptive(light: "F2F2F7", dark: "1C1C1E")
        static let surfaceSecondary = adaptive(light: "E5E5EA", dark: "2C2C2E")
        static let surfaceTertiary = adaptive(light: "D1D1D6", dark: "3C3C3E")

        // MARK: Adaptive Borders

        static let borderSubtle = adaptiveColor(
            light: UIColor.separator,
            dark: UIColor.white.withAlphaComponent(0.05)
        )
        static let borderMedium = adaptiveColor(
            light: UIColor.separator,
            dark: UIColor.white.withAlphaComponent(0.10)
        )

        // MARK: Adaptive Text

        static let textFaint = Color(hex: "6B7280")
        static let textMuted = Color(hex: "9CA3AF")

        // MARK: Summary Card Colors

        static let overdueCardBackground = adaptive(light: "FEF2F2", dark: "1C1C1E")
        static let overdueCardBorder = adaptiveColor(
            light: UIColor(Color(hex: "FEE2E2")),
            dark: UIColor.white.withAlphaComponent(0.15)
        )
        static let dueSoonCardBackground = adaptive(light: "FFFBEB", dark: "1C1C1E")
        static let dueSoonCardBorder = adaptiveColor(
            light: UIColor(Color(hex: "FDE68A")),
            dark: UIColor.white.withAlphaComponent(0.15)
        )
        static let allGoodCardBackground = adaptive(light: "ECFDF5", dark: "1C1C1E")
        static let allGoodCardBorder = adaptiveColor(
            light: UIColor(Color(hex: "A7F3D0")),
            dark: UIColor.white.withAlphaComponent(0.15)
        )

        // MARK: Action Buttons

        static let actionButtonBackground = adaptive(light: "2D3339", dark: "2C2C2E")
        static let actionButtonPressed = adaptive(light: "1F252B", dark: "3C3C3E")
        static let actionButtonIconBg = Color.white.opacity(0.1)

        // MARK: Notes Card

        static let notesBackground = adaptiveColor(
            light: UIColor(Color(hex: "FEFCE8").opacity(0.5)),
            dark: UIColor(Color(hex: "2C2C2E"))
        )
        static let notesBorder = adaptiveColor(
            light: UIColor(Color(hex: "FEF08A")),
            dark: UIColor.white.withAlphaComponent(0.05)
        )

        // MARK: Group Badge

        static let groupBadgeBackground = adaptiveColor(
            light: UIColor.systemGray5,
            dark: UIColor(Color(hex: "2C2C2E"))
        )
        static let groupBadgeText = adaptiveColor(
            light: UIColor.secondaryLabel,
            dark: UIColor(Color(hex: "9CA3AF"))
        )

        // MARK: Section Header

        static let sectionHeaderBg = adaptiveColor(
            light: UIColor.systemBackground.withAlphaComponent(0.95),
            dark: UIColor(Color(hex: "111111")).withAlphaComponent(0.95)
        )

        // MARK: Filters

        static let filterAccent = adaptive(light: "3D6B4F", dark: "6BCB77")

        // MARK: Sheet Overlay

        static let sheetOverlay = adaptiveColor(
            light: UIColor.black.withAlphaComponent(0.4),
            dark: UIColor.black.withAlphaComponent(0.6)
        )

        // MARK: Status Helpers

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

        // MARK: Adaptive Helpers

        /// Creates a Color that adapts between light and dark mode using hex strings.
        private static func adaptive(light: String, dark: String) -> Color {
            Color(UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(Color(hex: dark))
                    : UIColor(Color(hex: light))
            })
        }

        /// Creates a Color that adapts between light and dark mode using UIColors directly.
        private static func adaptiveColor(light: UIColor, dark: UIColor) -> Color {
            Color(UIColor { trait in
                trait.userInterfaceStyle == .dark ? dark : light
            })
        }

        // MARK: Theme-Aware Avatar Colors

        /// Returns muted background and text colors for avatars based on color scheme.
        /// Light mode: stored hex as background, white text.
        /// Dark mode: muted variants per dark mode addendum spec.
        static func avatarColors(for hex: String, scheme: ColorScheme) -> (background: Color, text: Color) {
            guard scheme == .dark else {
                return (Color(hex: hex), .white)
            }

            let normalized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).uppercased()
            switch normalized {
            case "6BCB77":  // Green
                return (Color(hex: "2D5040"), Color(hex: "4ADE80"))
            case "4ECDC4":  // Teal
                return (Color(hex: "0D3D3D"), Color(hex: "5EEAD4"))
            case "FF6B6B":  // Red / Orange-ish
                return (Color(hex: "3D2010"), Color(hex: "FDBA74"))
            case "F38181":  // Pink-Red
                return (Color(hex: "3D2010"), Color(hex: "FDBA74"))
            case "AA96DA":  // Purple
                return (Color(hex: "2D1B4E"), Color(hex: "D8B4FE"))
            case "FFD93D":  // Yellow / Amber
                return (Color(hex: "3D2E10"), Color(hex: "FCD34D"))
            case "95E1D3":  // Mint
                return (Color(hex: "0D3D3D"), Color(hex: "5EEAD4"))
            case "FCBAD3":  // Light Pink
                return (Color(hex: "2D1B4E"), Color(hex: "D8B4FE"))
            default:
                // Accent green fallback
                return (Color(hex: "3D6B4F"), .white)
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

        // New tokens for UX redesign (#171)
        static let summaryNumber = Font.system(size: 28, weight: .bold)
        static let summaryLabel = Font.system(size: 11, weight: .bold)
        static let sectionHeaderMono = Font.system(size: 11, weight: .bold, design: .monospaced)
        static let tabLabel = Font.system(size: 10, weight: .bold)
        static let sheetHeroName = Font.system(size: 24, weight: .bold)
        static let timelineTitle = Font.system(size: 14, weight: .bold)
        static let timelineMono = Font.system(size: 12, weight: .regular, design: .monospaced)
        static let timelineNotes = Font.system(size: 14, weight: .regular)
        static let homeTitle = Font.title.weight(.bold)
        static let homeSubtitle = Font.subheadline.weight(.medium)
        static let filterLabel = Font.footnote.weight(.semibold)
        static let filterChevron = Font.caption2.weight(.semibold)
        static let contactCardName = Font.system(size: 15, weight: .bold)
        static let contactCardMeta = Font.system(size: 13, weight: .medium)
        static let groupBadgeLabel = Font.system(size: 10, weight: .bold)
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let cardPadding: CGFloat = 14
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
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 32
        static let full: CGFloat = 999
    }

    // MARK: - Shadows

    enum Shadow {
        static let cardColor = Color.black.opacity(0.05)
        static let cardRadius: CGFloat = 2
        static let cardY: CGFloat = 1
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
    var dotOnly: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if dotOnly {
            let color = DS.Colors.statusColor(for: status)
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .shadow(
                    color: color.opacity(colorScheme == .dark ? 0.4 : 0.3),
                    radius: colorScheme == .dark ? 4 : 3
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(statusAccessibilityLabel)
        } else {
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
            .accessibilityLabel("Tag: \(name)")
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
