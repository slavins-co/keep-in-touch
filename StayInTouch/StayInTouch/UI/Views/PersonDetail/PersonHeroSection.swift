//
//  PersonHeroSection.swift
//  KeepInTouch
//

import SwiftUI

struct PersonHeroSection: View {
    @ObservedObject var viewModel: PersonDetailViewModel
    var onBirthdayEdit: () -> Void
    var onResumePrompt: () -> Void
    var onRemoveConfirm: () -> Void
    var onLinkContact: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, DS.Spacing.lg)

            if viewModel.person.contactUnavailable {
                unavailableContactBanner
            }

            if viewModel.person.isPaused {
                pausedBanner
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .center, spacing: DS.Spacing.sm) {
            ContactPhotoView(
                cnIdentifier: viewModel.person.cnIdentifier,
                displayName: viewModel.person.displayName,
                avatarColor: viewModel.person.avatarColor,
                size: 96
            )
            .overlay(Circle().stroke(DS.Colors.heroAvatarRing, lineWidth: 4))
            .shadow(color: .black.opacity(0.10), radius: 8, y: 6)

            Text(viewModel.person.displayName)
                .font(DS.Typography.sheetHeroName)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(statusLabel())
                .font(DS.Typography.detailStatusLine)
                .foregroundStyle(statusLineColor)
                .multilineTextAlignment(.center)

            if let birthday = viewModel.displayBirthday {
                Button {
                    onBirthdayEdit()
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "gift.fill")
                            .font(.caption)
                        Text(birthday.formatted)
                            .font(DS.Typography.contactCardMeta)
                    }
                    .foregroundStyle(Color(.secondaryLabel))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Birthday \(birthday.formatted)")
                .accessibilityHint("Opens birthday editor")
            }

            if !personGroups.isEmpty {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(personGroups.prefix(3), id: \.id) { group in
                        GroupPill(group: group)
                    }
                    if personGroups.count > 3 {
                        Text("+\(personGroups.count - 3)")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Banners

    private var unavailableContactBanner: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Info row
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Contact unavailable")
                        .font(DS.Typography.metadata.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("This contact may have been deleted or merged.")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }

            // Action row — horizontal, 44pt min targets
            HStack(spacing: DS.Spacing.lg) {
                Button {
                    onLinkContact()
                } label: {
                    Text("Link to Contact")
                        .font(DS.Typography.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, DS.Spacing.md)
                        .frame(minHeight: DS.Spacing.tapTarget)
                        .background(.white.opacity(0.3))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Link to a contact")
                .accessibilityHint("Opens contact picker to reconnect this person")

                Button {
                    onRemoveConfirm()
                } label: {
                    Text("Remove")
                        .font(DS.Typography.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(minHeight: DS.Spacing.tapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.statusDueSoon)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .padding(.bottom, DS.Spacing.md)
    }

    private var pausedBanner: some View {
        HStack {
            Text("Tracking paused")
                .font(DS.Typography.metadata)
            Spacer()
            Button("Resume") { onResumePrompt() }
                .buttonStyle(.borderedProminent)
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.statusUnknown.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .padding(.bottom, DS.Spacing.md)
    }

    // MARK: - Computed Properties

    private var personGroups: [Group] {
        viewModel.groups.filter { viewModel.person.groupIds.contains($0.id) }
    }

    private var currentStatus: ContactStatus {
        guard let cadence = viewModel.cadence else { return .onTrack }
        return FrequencyCalculator().status(for: viewModel.person, in: [cadence])
    }

    private var daysOverdue: Int {
        guard let cadence = viewModel.cadence else { return 0 }
        return FrequencyCalculator().daysOverdue(for: viewModel.person, in: [cadence])
    }

    private var daysUntilDue: Int {
        guard let cadence = viewModel.cadence else { return 0 }
        let calculator = FrequencyCalculator()
        guard let dueDate = calculator.effectiveDueDate(for: viewModel.person, in: [cadence]) else { return 0 }
        let cal = Calendar.current
        return max(0, cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: dueDate)).day ?? 0)
    }

    private func statusLabel() -> String {
        let cadenceName = viewModel.cadence?.name ?? "Frequency"

        if viewModel.person.isPaused {
            return "\(cadenceName) \u{00B7} Paused"
        }

        if let snoozedUntil = viewModel.person.snoozedUntil, snoozedUntil > Date() {
            let formatted = Self.dueDateFormatter.string(from: snoozedUntil)
            return "\(cadenceName) \u{00B7} Snoozed until \(formatted)"
        }

        switch currentStatus {
        case .onTrack:
            return "\(cadenceName) \u{00B7} All good"
        case .dueSoon:
            let days = daysUntilDue
            return days > 0 ? "\(cadenceName) \u{00B7} Due in \(days)d" : "\(cadenceName) \u{00B7} Check in soon"
        case .overdue:
            let days = daysOverdue
            if days >= 14 {
                let weeks = days / 7
                return "\(cadenceName) \u{00B7} Overdue by \(weeks) week\(weeks == 1 ? "" : "s")"
            }
            return "\(cadenceName) \u{00B7} Overdue by \(days) day\(days == 1 ? "" : "s")"
        case .unknown:
            return "\(cadenceName) \u{00B7} No connections yet"
        }
    }

    private var statusLineColor: Color {
        if viewModel.person.isPaused {
            return DS.Colors.textMuted
        }
        if let snoozedUntil = viewModel.person.snoozedUntil, snoozedUntil > Date() {
            return DS.Colors.textMuted
        }
        return DS.Colors.statusColor(for: currentStatus)
    }

    private static let dueDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()
}
