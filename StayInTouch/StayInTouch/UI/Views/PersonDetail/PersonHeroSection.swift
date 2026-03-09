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

            if !personTags.isEmpty {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(personTags.prefix(3), id: \.id) { tag in
                        TagPill(tag: tag)
                    }
                    if personTags.count > 3 {
                        Text("+\(personTags.count - 3)")
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
            Spacer()
            VStack(spacing: DS.Spacing.xs) {
                Button("Link") { onLinkContact() }
                    .font(DS.Typography.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(.white.opacity(0.3))
                    .clipShape(Capsule())
                Button("Remove") { onRemoveConfirm() }
                    .font(DS.Typography.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xs)
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

    private var personTags: [Tag] {
        viewModel.tags.filter { viewModel.person.tagIds.contains($0.id) }
    }

    private var currentStatus: ContactStatus {
        guard let group = viewModel.group else { return .onTrack }
        return FrequencyCalculator().status(for: viewModel.person, in: [group])
    }

    private var daysOverdue: Int {
        guard let group = viewModel.group else { return 0 }
        return FrequencyCalculator().daysOverdue(for: viewModel.person, in: [group])
    }

    private var daysUntilDue: Int {
        guard let group = viewModel.group else { return 0 }
        let calculator = FrequencyCalculator()
        guard let dueDate = calculator.effectiveDueDate(for: viewModel.person, in: [group]) else { return 0 }
        let cal = Calendar.current
        return max(0, cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: dueDate)).day ?? 0)
    }

    private func statusLabel() -> String {
        let groupName = viewModel.group?.name ?? "Frequency"

        if viewModel.person.isPaused {
            return "\(groupName) \u{00B7} Paused"
        }

        if let snoozedUntil = viewModel.person.snoozedUntil, snoozedUntil > Date() {
            let formatted = Self.dueDateFormatter.string(from: snoozedUntil)
            return "\(groupName) \u{00B7} Snoozed until \(formatted)"
        }

        switch currentStatus {
        case .onTrack:
            return "\(groupName) \u{00B7} All good"
        case .dueSoon:
            let days = daysUntilDue
            return days > 0 ? "\(groupName) \u{00B7} Due in \(days)d" : "\(groupName) \u{00B7} Check in soon"
        case .overdue:
            let days = daysOverdue
            if days >= 14 {
                let weeks = days / 7
                return "\(groupName) \u{00B7} Overdue by \(weeks) week\(weeks == 1 ? "" : "s")"
            }
            return "\(groupName) \u{00B7} Overdue by \(days) day\(days == 1 ? "" : "s")"
        case .unknown:
            return "\(groupName) \u{00B7} No connections yet"
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
