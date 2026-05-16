//
//  TutorialPersonDetailHost.swift
//  KeepInTouch
//
//  Hosts a preview-mode PersonDetailView for Walkthrough B. The hosted view
//  reads from in-memory `TutorialDemoData` and never touches Core Data.
//

import SwiftUI

struct TutorialPersonDetailHost: View {
    var body: some View {
        PersonDetailView(
            person: TutorialDemoData.person,
            mode: .preview(TutorialDemoData.previewData)
        )
    }
}
