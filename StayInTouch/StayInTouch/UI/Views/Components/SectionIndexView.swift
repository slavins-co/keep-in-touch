//
//  SectionIndexView.swift
//  KeepInTouch
//
//  Created by Claude Code on 2/4/26.
//

import SwiftUI

struct SectionIndexView: View {
    let sections: [String]
    let onTap: (String) -> Void

    var body: some View {
        VStack(spacing: 1) {
            ForEach(sections, id: \.self) { section in
                Button(action: {
                    onTap(section)
                }) {
                    Text(section)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(DS.Colors.accent)
                        .frame(minWidth: 24, minHeight: 18)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Jump to section \(section)")
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
    }
}
