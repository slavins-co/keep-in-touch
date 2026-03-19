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

        static let textFaint = adaptiveColor(light: UIColor(Color(hex: "4B5563")), dark: UIColor(Color(hex: "6B7280")))
        static let textMuted = adaptiveColor(light: UIColor(Color(hex: "6B7280")), dark: UIColor(Color(hex: "9CA3AF")))

        // MARK: Summary Card Colors

        static let overdueCardBackground = adaptive(light: "FEF2F2", dark: "1C1C1E")
        // DESIGN: Light/dark structural difference — summary cards: tinted bg + colored border light / neutral #1C1C1E + white/5% border dark
        static let overdueCardBorder = adaptiveColor(
            light: UIColor(Color(hex: "FEE2E2")),
            dark: UIColor.white.withAlphaComponent(0.05)
        )
        static let dueSoonCardBackground = adaptive(light: "FFFBEB", dark: "1C1C1E")
        static let dueSoonCardBorder = adaptiveColor(
            light: UIColor(Color(hex: "FDE68A")),
            dark: UIColor.white.withAlphaComponent(0.05)
        )
        static let allGoodCardBackground = adaptive(light: "ECFDF5", dark: "1C1C1E")
        static let allGoodCardBorder = adaptiveColor(
            light: UIColor(Color(hex: "A7F3D0")),
            dark: UIColor.white.withAlphaComponent(0.05)
        )

        // MARK: Action Buttons

        static let actionButtonBackground = adaptive(light: "2D3339", dark: "2C2C2E")
        static let actionButtonPressed = adaptive(light: "1F252B", dark: "3C3C3E")
        static let actionButtonIconBg = Color.white.opacity(0.1)
        // DESIGN: Light/dark structural difference — action button icon circles: white/10% circle in light / absent in dark (direct white icons)
        static let actionButtonIconCircleOpacity = adaptiveColor(
            light: UIColor.white.withAlphaComponent(0.1),
            dark: UIColor.clear
        )
        static let actionButtonBorder = adaptiveColor(
            light: UIColor.clear,
            dark: UIColor.white.withAlphaComponent(0.05)
        )
        static let actionButtonShadow = adaptiveColor(
            light: UIColor.black.withAlphaComponent(0.1),
            dark: UIColor.clear
        )

        // MARK: Notes Card

        // DESIGN: Light/dark structural difference — notes card: yellow-50 tint light / neutral #2C2C2E dark
        static let notesBackground = adaptiveColor(
            light: UIColor(Color(hex: "FEFCE8").opacity(0.5)),
            dark: UIColor(Color(hex: "2C2C2E"))
        )
        static let notesBorder = adaptiveColor(
            light: UIColor(Color(hex: "FEF08A")),
            dark: UIColor.white.withAlphaComponent(0.05)
        )
        // DESIGN: Light/dark structural difference — notes focus ring: yellow light / gray dark
        static let notesFocusRing = adaptiveColor(
            light: UIColor(Color(hex: "FDE68A")),
            dark: UIColor(Color(hex: "6B7280"))
        )
        static let notesText = adaptiveColor(
            light: UIColor.label,
            dark: UIColor(Color(hex: "D1D5DB"))
        )
        static let notesPlaceholder = adaptiveColor(
            light: UIColor.placeholderText,
            dark: UIColor(Color(hex: "6B7280"))
        )

        // MARK: Timeline

        static let timelineLine = adaptiveColor(
            light: UIColor.systemGray5,
            dark: UIColor.white.withAlphaComponent(0.10)
        )
        static let timelineCircleFill = adaptiveColor(
            light: UIColor.white,
            dark: UIColor(Color(hex: "1C1C1E"))
        )
        static let timelineCircleLatest = adaptive(light: "10B981", dark: "10B981")
        static let timelineCircleOther = adaptiveColor(
            light: UIColor.systemGray3,
            dark: UIColor(Color(hex: "4B5563"))
        )

        // MARK: Contact Settings

        static let settingsGearIcon = adaptiveColor(
            light: UIColor.secondaryLabel,
            dark: UIColor(Color(hex: "6B7280"))
        )
        static let settingsTitle = adaptiveColor(
            light: UIColor.label,
            dark: UIColor.white
        )
        static let settingsChevron = adaptiveColor(
            light: UIColor.secondaryLabel,
            dark: UIColor(Color(hex: "6B7280"))
        )
        static let settingsItemLabel = adaptiveColor(
            light: UIColor.secondaryLabel,
            dark: UIColor(Color(hex: "9CA3AF"))
        )
        static let settingsItemValue = adaptiveColor(
            light: UIColor.label,
            dark: UIColor(Color(hex: "D1D5DB"))
        )
        static let settingsSeparator = adaptiveColor(
            light: UIColor.separator,
            dark: UIColor.white.withAlphaComponent(0.05)
        )
        static let settingsRemoveText = adaptiveColor(
            light: UIColor.systemRed,
            dark: UIColor(Color(hex: "F87171"))
        )
        static let settingsCardBg = adaptiveColor(
            light: UIColor.systemGray6,
            dark: UIColor(Color(hex: "1C1C1E"))
        )
        static let settingsIconCircle = adaptiveColor(
            light: UIColor.systemGray5,
            dark: UIColor.white.withAlphaComponent(0.10)
        )
        static let settingsSnoozePillBorder = adaptiveColor(
            light: UIColor.systemGray4,
            dark: UIColor.white.withAlphaComponent(0.15)
        )
        static let settingsSnoozeActive = adaptiveColor(
            light: UIColor.systemPurple,
            dark: UIColor(Color(hex: "C084FC"))
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

        // MARK: Search Bar

        static let searchBarBackground = adaptiveColor(
            light: UIColor.white,
            dark: UIColor(Color(hex: "1C1C1E"))
        )
        static let searchBarIcon = adaptiveColor(
            light: UIColor.tertiaryLabel,
            dark: UIColor(Color(hex: "9CA3AF"))
        )
        // DESIGN: Light/dark structural difference — search focus ring: accent green light / gray-600 dark
        static let searchBarFocusRing = adaptiveColor(
            light: UIColor(Color(hex: "3D6B4F")),
            dark: UIColor.systemGray3
        )
        static let searchBarBorder = adaptiveColor(
            light: UIColor.systemGray5,
            dark: UIColor.white.withAlphaComponent(0.10)
        )
        static let searchBarShadow = adaptiveColor(
            light: UIColor.black.withAlphaComponent(0.1),
            dark: UIColor.clear
        )

        // MARK: Filters

        static let filterAccent = adaptive(light: "3D6B4F", dark: "6BCB77")

        // MARK: Detail Hero

        static let heroAccentGreen = adaptive(light: "3D6B4F", dark: "3D6B4F")
        // DESIGN: Light/dark structural difference — hero avatar ring: solid white 4px light / white/5% dark
        static let heroAvatarRing = adaptiveColor(
            light: UIColor.white,
            dark: UIColor.white.withAlphaComponent(0.05)
        )
        static let ctaContainerBg = adaptiveColor(
            light: UIColor.systemBackground,
            dark: UIColor(Color(hex: "1C1C1E"))
        )
        static let ctaShadow = adaptiveColor(
            light: UIColor(Color(hex: "3D6B4F").opacity(0.3)),
            dark: UIColor(Color(hex: "064E3B").opacity(0.2))
        )

        // MARK: Sheet Overlay

        // DESIGN: Light/dark structural difference — sheet overlay: black/40% light / black/60% dark
        static let sheetOverlay = adaptiveColor(
            light: UIColor.black.withAlphaComponent(0.4),
            dark: UIColor.black.withAlphaComponent(0.6)
        )

        // MARK: Sheet Chrome

        static let sheetDragHandle = adaptiveColor(
            light: UIColor.systemGray3,
            dark: UIColor.white.withAlphaComponent(0.2)
        )
        static let sheetCloseButtonFg = adaptiveColor(
            light: UIColor.secondaryLabel,
            dark: UIColor(Color(hex: "9CA3AF"))
        )
        static let sheetCloseButtonBg = adaptiveColor(
            light: UIColor.systemGray5,
            dark: UIColor(Color(hex: "2C2C2E"))
        )

        // MARK: Row Separator

        static let rowSeparator = adaptiveColor(
            light: UIColor.systemGray6,
            dark: UIColor.white.withAlphaComponent(0.05)
        )

        // MARK: Summary Card Dark-Mode Overrides

        /// Shadow: visible in light, absent in dark
        static let summaryCardShadow = adaptiveColor(
            light: UIColor.black.withAlphaComponent(0.05),
            dark: UIColor.clear
        )
        /// Label color: status-colored in light, gray-500 in dark
        static let summaryLabelOverdue = adaptiveColor(
            light: UIColor(Color(hex: "FF3B30")),
            dark: UIColor(Color(hex: "6B7280"))
        )
        static let summaryLabelDueSoon = adaptiveColor(
            light: UIColor(Color(hex: "FF9500")),
            dark: UIColor(Color(hex: "6B7280"))
        )
        static let summaryLabelAllGood = adaptiveColor(
            light: UIColor(Color(hex: "34C759")),
            dark: UIColor(Color(hex: "6B7280"))
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

        // DESIGN: Light/dark structural difference — summary card: .title light / .title2 dark
        static func summaryNumber(scheme: ColorScheme) -> Font {
            scheme == .dark ? Font.title2.weight(.bold) : Font.title.weight(.bold)
        }
        static let summaryLabel = Font.caption2.weight(.bold)
        static let sectionHeaderMono = Font.system(.caption2, design: .monospaced).weight(.bold)
        static let tabLabel = Font.caption2.weight(.bold)
        static let sheetHeroName = Font.title2.weight(.bold)
        static let timelineTitle = Font.subheadline.weight(.bold)
        static let timelineMono = Font.system(.caption, design: .monospaced)
        static let timelineNotes = Font.subheadline
        static let homeTitle = Font.title.weight(.bold)
        static let homeSubtitle = Font.subheadline.weight(.medium)
        static let filterLabel = Font.footnote.weight(.semibold)
        static let filterChevron = Font.caption2.weight(.semibold)
        static let contactCardName = Font.subheadline.weight(.bold)
        static let contactCardMeta = Font.footnote.weight(.medium)
        static let groupBadgeLabel = Font.caption2.weight(.bold)
        static let detailStatusLine = Font.subheadline.weight(.semibold)
        static let ctaButton = Font.callout.weight(.bold)

        // Tokens for #177 (notes, timeline, settings)
        static let notesLabel = Font.caption2.weight(.bold)
        static let notesBody = Font.body
        static let settingsHeaderTitle = Font.body.weight(.semibold)
        static let settingsRowLabel = Font.body
        static let settingsSectionLabel = Font.caption.weight(.semibold)

        // Decorative icon — fixed size, not text content (Apple HIG: decorative elements exempt from Dynamic Type)
        static let onboardingIcon = Font.system(size: 56)
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
        static let tapTarget: CGFloat = 44  // Apple HIG minimum tap target

        // MARK: Adaptive Layout Values
        // Font sizes and CGFloat values cannot use UIColor trait-based adaptation,
        // so these functions accept `scheme:` as a pragmatic alternative.

        // DESIGN: Light/dark structural difference — contact row padding: 14px light / 16px dark
        static func contactCardVerticalPadding(scheme: ColorScheme) -> CGFloat {
            scheme == .dark ? lg : cardPadding
        }

        // DESIGN: Light/dark structural difference — avatar-to-text spacing: 14px light / 16px dark
        static func contactCardAvatarSpacing(scheme: ColorScheme) -> CGFloat {
            scheme == .dark ? lg : cardPadding
        }

        // DESIGN: Light/dark structural difference — section header letter spacing: 1.65 light / 2.2 dark
        static func sectionHeaderTracking(scheme: ColorScheme) -> CGFloat {
            scheme == .dark ? 2.2 : 1.65
        }
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
            .accessibilityHidden(true)
    }
}

struct StatusIndicator: View {
    let status: ContactStatus
    var daysOverdue: Int = 0
    var dotOnly: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if dotOnly {
            // DESIGN: Light/dark structural difference — status dot: drop shadow light / colored glow dark
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

// MARK: - Button Styles

/// Primary CTA button for onboarding and full-width actions.
/// Capsule shape, accent green background, white text.
struct OnboardingPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typography.ctaButton)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
            .background(configuration.isPressed ? DS.Colors.accent.opacity(0.8) : DS.Colors.accent)
            .clipShape(Capsule())
    }
}
