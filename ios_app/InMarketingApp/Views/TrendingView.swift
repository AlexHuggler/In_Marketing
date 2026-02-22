import SwiftUI

struct TrendingView: View {
    @EnvironmentObject var viewModel: ResearchViewModel
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $selectedTab) {
                    Text("Trending").tag(0)
                    Text("Hashtags").tag(1)
                    Text("Best Times").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(DS.Spacing.lg)
                .onChange(of: selectedTab) { _, _ in Haptics.select() }

                ScrollView {
                    switch selectedTab {
                    case 0: trendingTopicsSection
                    case 1: hashtagsSection
                    case 2: bestTimesSection
                    default: EmptyView()
                    }
                }
                .refreshable {
                    Haptics.tap()
                    viewModel.generateAllReports()
                }
            }
            .navigationTitle("Trends & Timing")
        }
    }

    // MARK: - Trending Topics

    private var trendingTopicsSection: some View {
        VStack(spacing: DS.Spacing.md) {
            if let report = viewModel.trendingReport, !report.trendingNow.isEmpty {
                ForEach(Array(report.trendingNow.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: DS.Spacing.md) {
                        Text("\(index + 1)")
                            .font(DS.Typo.sectionTitle)
                            .foregroundStyle(DS.Colors.secondaryText)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text(item.topic)
                                .font(DS.Typo.cardTitle)
                            Text("\(item.postCount) posts | \(Int(item.avgEngagement)) avg engagement")
                                .font(DS.Typo.caption)
                                .foregroundStyle(DS.Colors.secondaryText)
                        }

                        Spacer()

                        HStack(spacing: 2) {
                            Image(systemName: item.growthRate >= 0 ? "arrow.up.right" : "arrow.down.right")
                            Text(String(format: "%.0f%%", item.growthRate))
                        }
                        .font(DS.Typo.bodyBold)
                        .foregroundStyle(item.growthRate >= 0 ? DS.Colors.success : DS.Colors.danger)
                    }
                    .padding(DS.Spacing.lg)
                    .background(DS.Colors.surfaceBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm + 2))
                    .staggeredAppear(index: index)
                }
            } else {
                EmptyStateView(
                    icon: "flame",
                    message: "No trending data available.\nImport posts to see what's trending.",
                    actionLabel: "Refresh",
                    action: { viewModel.generateAllReports() }
                )
            }
        }
        .padding(DS.Spacing.lg)
    }

    // MARK: - Hashtags

    private var hashtagsSection: some View {
        VStack(spacing: DS.Spacing.md) {
            if let report = viewModel.trendingReport, !report.topHashtags.isEmpty {
                ForEach(Array(report.topHashtags.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: DS.Spacing.md) {
                        Text("\(index + 1)")
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                            .frame(width: 24)

                        Text(item.hashtag)
                            .font(DS.Typo.cardTitle)
                            .foregroundStyle(DS.Colors.accent)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "%.0f avg eng", item.avgEngagement))
                                .font(DS.Typo.bodyBold)
                            Text("\(item.postCount) posts")
                                .font(DS.Typo.caption)
                                .foregroundStyle(DS.Colors.secondaryText)
                        }
                    }
                    .padding(DS.Spacing.lg)
                    .background(DS.Colors.surfaceBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm + 2))
                    .staggeredAppear(index: index)
                }
            } else {
                EmptyStateView(icon: "number", message: "No hashtag data available")
            }
        }
        .padding(DS.Spacing.lg)
    }

    // MARK: - Best Times

    private var bestTimesSection: some View {
        VStack(spacing: DS.Spacing.xl) {
            if let report = viewModel.trendingReport {
                // Best Days
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    SectionHeader(title: "Best Days to Post", icon: "calendar")

                    ForEach(report.bestPostingTimes.bestDays) { day in
                        HStack {
                            Text(day.label)
                                .font(DS.Typo.body)
                                .frame(width: 100, alignment: .leading)

                            GeometryReader { geo in
                                let maxEng = report.bestPostingTimes.bestDays.map(\.avgEngagement).max() ?? 1
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(DS.Colors.surfaceBackground)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(DS.Colors.accent)
                                        .frame(width: geo.size.width * (day.avgEngagement / maxEng))
                                }
                            }
                            .frame(height: 20)

                            Text(String(format: "%.0f", day.avgEngagement))
                                .font(DS.Typo.caption)
                                .foregroundStyle(DS.Colors.secondaryText)
                                .frame(width: 50, alignment: .trailing)
                        }
                    }
                }
                .cardStyle()

                // Best Hours
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    SectionHeader(title: "Best Hours to Post", icon: "clock.fill")

                    ForEach(report.bestPostingTimes.bestHours.prefix(10)) { hour in
                        HStack {
                            Text(hour.label)
                                .font(DS.Typo.body)
                                .frame(width: 60, alignment: .leading)

                            GeometryReader { geo in
                                let maxEng = report.bestPostingTimes.bestHours.map(\.avgEngagement).max() ?? 1
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(DS.Colors.surfaceBackground)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(DS.Colors.trendOrange)
                                        .frame(width: geo.size.width * (hour.avgEngagement / maxEng))
                                }
                            }
                            .frame(height: 20)

                            Text(String(format: "%.0f", hour.avgEngagement))
                                .font(DS.Typo.caption)
                                .foregroundStyle(DS.Colors.secondaryText)
                                .frame(width: 50, alignment: .trailing)
                        }
                    }
                }
                .cardStyle()
            } else {
                EmptyStateView(icon: "clock", message: "No timing data available")
            }
        }
        .padding(DS.Spacing.lg)
    }
}
