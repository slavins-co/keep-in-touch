//
//  LimitedContactsAccessBanner.swift
//  StayInTouch
//

import SwiftUI

struct LimitedContactsAccessBanner: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Limited Contact Access")
                        .font(DS.Typography.caption)
                        .fontWeight(.semibold)
                    Text("Some contacts may not appear. Tap to update in Settings.")
                        .font(DS.Typography.metadata)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(DS.Colors.tertiaryText)
            }
            .padding(DS.Spacing.sm)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
