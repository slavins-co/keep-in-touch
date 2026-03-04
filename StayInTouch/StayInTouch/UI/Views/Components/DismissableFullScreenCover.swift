//
//  DismissableFullScreenCover.swift
//  KeepInTouch
//

import SwiftUI

/// Reusable full-screen cover wrapper with rounded top corners,
/// drag handle, close button, and drag-to-dismiss gesture.
struct DismissableFullScreenCover<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var dragOffset: CGFloat = 0

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Transparent tap target — dismiss when tapping outside the card.
            // Dimming lives on the presenting view (MainTabView) so it fades
            // independently instead of sliding with the fullScreenCover.
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }

            // Sheet content
            VStack(spacing: 0) {
                sheetHeader
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(DS.Colors.pageBg)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(DS.Colors.borderMedium)
                    .frame(height: 0.5)
            }
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: DS.Radius.xxl,
                topTrailingRadius: DS.Radius.xxl
            ))
            .offset(y: max(0, dragOffset))
        }
        .presentationBackground(.clear)
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack {
            Spacer()
            RoundedRectangle(cornerRadius: 3)
                .fill(dragHandleColor)
                .frame(width: 40, height: 6)
            Spacer()
        }
        .overlay(alignment: .trailing) {
            closeButton
                .padding(.trailing, DS.Spacing.lg)
        }
        .padding(.top, DS.Spacing.xl)
        .padding(.bottom, DS.Spacing.sm)
        .contentShape(Rectangle())
        .gesture(dragGesture)
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(closeButtonForeground)
                .frame(width: 28, height: 28)
                .background(closeButtonBackground)
                .clipShape(Circle())
        }
        .accessibilityLabel("Close")
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if value.translation.height > 0 {
                    dragOffset = value.translation.height
                }
            }
            .onEnded { value in
                let shouldDismiss = value.translation.height > 100
                    || value.predictedEndTranslation.height > 300

                if shouldDismiss {
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.3)) {
                        dragOffset = 0
                    }
                }
            }
    }

    // MARK: - Adaptive Colors

    private var dragHandleColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.2)
            : Color(.systemGray3)
    }

    private var closeButtonForeground: Color {
        colorScheme == .dark
            ? Color(hex: "9CA3AF")
            : Color(.secondaryLabel)
    }

    private var closeButtonBackground: Color {
        colorScheme == .dark
            ? DS.Colors.surfaceSecondary
            : Color(.systemGray5)
    }
}
