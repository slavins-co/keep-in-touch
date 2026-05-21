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
        .onChange(of: viewModel.range) { _, _ in viewModel.load() }
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
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 44))
                .foregroundStyle(DS.Colors.secondaryText)
            Text("No data yet")
                .font(DS.Typography.title)
            Text("Log a few touches and check back \u{2014} insights appear here once you have history to summarize.")
                .font(DS.Typography.metadata)
                .foregroundStyle(DS.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xxxl)
    }

    private var emptyForRange: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 36))
                .foregroundStyle(DS.Colors.secondaryText)
            Text("No touches in this range")
                .font(DS.Typography.title)
            if viewModel.range == .days30 {
                Text("Try expanding to 90 days.")
                    .font(DS.Typography.metadata)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xxl)
    }
}
