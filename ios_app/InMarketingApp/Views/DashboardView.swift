import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var viewModel: ResearchViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    if let summary = viewModel.executiveSummary {
                        overviewSection(summary.overview)
                            .staggeredAppear(index: 0)
                        topCreatorsSection(summary.topCreators)
                            .staggeredAppear(index: 1)
                        fastestGrowingSection(summary.fastestGrowing)
                            .staggeredAppear(index: 2)
                        topHashtagsSection(summary.topHashtags)
                            .staggeredAppear(index: 3)
                        trendingSection(summary.trendingTopics)
                            .staggeredAppear(index: 4)
                        winningFormulasSection(summary.winningFormulas)
                            .staggeredAppear(index: 5)
                        whitespaceSection(summary.whitespaceOpportunities)
                            .staggeredAppear(index: 6)
                        recommendationsSection(summary.recommendations)
                            .staggeredAppear(index: 7)
                    } else if viewModel.isLoading {
                        VStack(spacing: DS.Spacing.md) {
                            ProgressView()
                                .controlSize(.large)
                            Text("Analyzing posts and creators...")
                                .font(DS.Typo.body)
                                .foregroundStyle(DS.Colors.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 120)
                    } else {
                        EmptyStateView(
                            icon: "chart.bar.xaxis",
                            message: "No analysis available yet.\nLoad data to get started.",
                            actionLabel: "Load Sample Data",
                            action: { viewModel.loadSampleData() }
                        )
                    }
                }
                .padding(DS.Spacing.lg)
            }
            .refreshable {
                Haptics.tap()
                viewModel.generateAllReports()
            }
            .navigationTitle("Executive Summary")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.tap()
                        viewModel.loadSampleData()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh data")
                }
            }
        }
    }

    // MARK: - Overview

    private func overviewSection(_ overview: OverviewMetrics) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            SectionHeader(title: "Overview", icon: "chart.bar.fill")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.md) {
                MetricCard(title: "Posts Analyzed", value: "\(overview.totalPostsAnalyzed)", icon: "doc.text.fill", color: DS.Colors.accent)
                MetricCard(title: "Creators Tracked", value: "\(overview.totalCreatorsTracked)", icon: "person.3.fill", color: DS.Colors.info)
                MetricCard(title: "Avg Engagement", value: String(format: "%.2f%%", overview.averageEngagementRate), icon: "heart.fill", color: DS.Colors.engagementPink)
                MetricCard(title: "Top Engagement", value: String(format: "%.2f%%", overview.topEngagementRate), icon: "star.fill", color: DS.Colors.trendOrange)
            }
        }
    }

    // MARK: - Top Creators

    private func topCreatorsSection(_ creators: [CreatorRankingItem]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            SectionHeader(title: "Top Creators by Engagement", icon: "person.crop.circle.badge.checkmark")

            ForEach(Array(creators.prefix(5).enumerated()), id: \.element.id) { index, creator in
                HStack(spacing: DS.Spacing.md) {
                    Text("\(index + 1)")
                        .font(DS.Typo.sectionTitle)
                        .foregroundStyle(DS.Colors.secondaryText)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(creator.displayName)
                            .font(DS.Typo.cardTitle)
                        HStack(spacing: DS.Spacing.sm) {
                            Label(creator.platform.displayName, systemImage: creator.platform.iconName)
                                .font(DS.Typo.caption)
                                .foregroundStyle(DS.Colors.secondaryText)
                            Text(creator.tier)
                                .font(DS.Typo.badge)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(DS.Colors.surfaceBackground)
                                .clipShape(Capsule())
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f%%", creator.avgEngagementRate))
                            .font(DS.Typo.sectionTitle)
                            .foregroundStyle(DS.Colors.accent)
                        Text(formatNumber(creator.followerCount) + " followers")
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                    }
                }
                .padding(.vertical, DS.Spacing.sm)

                if index < min(creators.count, 5) - 1 { Divider() }
            }
        }
        .cardStyle()
    }

    // MARK: - Fastest Growing

    private func fastestGrowingSection(_ items: [GrowthItem]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            SectionHeader(title: "Fastest Growing", icon: "arrow.up.right.circle.fill")

            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack {
                    Text("\(index + 1). \(item.name)")
                        .font(DS.Typo.body)
                    Spacer()
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: item.growthRate >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2)
                        Text(String(format: "%.1f%%", item.growthRate))
                    }
                    .font(DS.Typo.body)
                    .foregroundStyle(item.growthRate >= 0 ? DS.Colors.success : DS.Colors.danger)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Top Hashtags

    private func topHashtagsSection(_ items: [HashtagItem]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            SectionHeader(title: "Top Hashtags", icon: "number")

            ForEach(items) { item in
                HStack {
                    Text(item.hashtag)
                        .font(DS.Typo.bodyBold)
                        .foregroundStyle(DS.Colors.accent)
                    Spacer()
                    Text("\(Int(item.avgEngagement)) avg eng")
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                    Text("(\(item.postCount) posts)")
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.Colors.tertiaryText)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Trending

    private func trendingSection(_ items: [TrendItem]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            SectionHeader(title: "Trending Topics", icon: "flame.fill")

            ForEach(items) { item in
                HStack {
                    Text(item.topic)
                        .font(DS.Typo.body)
                    Spacer()
                    Text(String(format: "%.0f%%", item.growthRate) + " growth")
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.Colors.trendOrange)
                    Text("(\(item.postCount) posts)")
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Winning Formulas

    private func winningFormulasSection(_ items: [FormulaItem]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            SectionHeader(title: "Winning Content Formulas", icon: "trophy.fill")

            ForEach(items) { item in
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(item.formula)
                        .font(DS.Typo.bodyBold)
                    Text(String(format: "%.0f%% success rate | %.0f avg engagement", item.successRate, item.avgEngagement))
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
                .padding(.vertical, DS.Spacing.xs)
            }
        }
        .cardStyle()
    }

    // MARK: - Whitespace

    private func whitespaceSection(_ items: [WhitespaceItem]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            SectionHeader(title: "Whitespace Opportunities", icon: "sparkles")

            ForEach(items) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.topic.capitalized)
                            .font(DS.Typo.bodyBold)
                        Text("\(item.creatorCount) creators | Score: \(String(format: "%.0f", item.opportunityScore))")
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                    }
                    Spacer()
                    PriorityBadge(priority: item.priority)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Recommendations

    private func recommendationsSection(_ recs: [String]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            SectionHeader(title: "Key Recommendations", icon: "lightbulb.fill")

            ForEach(Array(recs.enumerated()), id: \.offset) { index, rec in
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    Text("\(index + 1).")
                        .font(DS.Typo.bodyBold)
                        .foregroundStyle(DS.Colors.accent)
                    Text(rec)
                        .font(DS.Typo.body)
                }
            }
        }
        .cardStyle()
    }
}
