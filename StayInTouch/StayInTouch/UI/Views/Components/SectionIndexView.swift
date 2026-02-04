//
//  SectionIndexView.swift
//  StayInTouch
//
//  Created by Claude Code on 2/4/26.
//

import SwiftUI

struct SectionIndexView: View {
    let sections: [String]
    let onTap: (String) -> Void

    var body: some View {
        VStack(spacing: 2) {
            ForEach(sections, id: \.self) { section in
                Button(action: {
                    onTap(section)
                }) {
                    Text(section)
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .frame(minWidth: 20, minHeight: 20)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(Color(uiColor: .systemBackground).opacity(0.8))
        .cornerRadius(8)
    }
}
