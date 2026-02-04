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
                Text(section)
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .onTapGesture {
                        onTap(section)
                    }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}
