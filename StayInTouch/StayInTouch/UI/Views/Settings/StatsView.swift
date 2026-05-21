//
//  StatsView.swift
//  KeepInTouch
//

import SwiftUI

struct StatsView: View {
    @StateObject private var viewModel: StatsViewModel

    init(viewModel: StatsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                rangePicker
                content
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.lg)
        }
        .background(DS.Colors.groupedBackground)
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.load() }
        .onChange(of: viewModel.range) { _, _ in
            withAnimation(.easeInOut(duration: 0.35)) {
                viewModel.load()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .personDidChange)) { _ in
            viewModel.load()
        }
    }

    private var rangePicker: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Picker("Range", selection: $viewModel.range) {
                ForEach(StatsRange.allCases) { range in
                    Text(range.displayName).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Time range")

            Text(viewModel.range.subtitle)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondaryText)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.snapshot?.state {
        case .none, .some(.empty):
            emptyAllTime
        case .some(.emptyForRange):
            emptyForRange
        case .some(.ready(let cadenceRows, let methodRows, let total)):
            VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                CadencePerformanceChart(rows: cadenceRows, range: viewModel.range)
                MethodBreakdownChart(rows: methodRows, totalEvents: total)
            }
        }
    }

    private var emptyAllTime: some View {
        EmptyStateView(
            title: "No data yet",
            message: "Log a few connections and check back \u{2014} insights appear here once you have history to summarize.",
            systemImage: "chart.bar.xaxis"
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xxxl)
    }

    private var emptyForRange: some View {
        EmptyStateView(
            title: "No connections in this range",
            message: viewModel.range == .days30 ? "Try expanding to 90 days." : "",
            systemImage: "calendar.badge.exclamationmark"
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xxl)
    }
}
