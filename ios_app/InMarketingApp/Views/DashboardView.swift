import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var viewModel: ResearchViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Overview Cards
                    if let summary = viewModel.executiveSummary {
                        overviewSection(summary.overview)
                        topCreatorsSection(summary.topCreators)
                        fastestGrowingSection(summary.fastestGrowing)
                        topHashtagsSection(summary.topHashtags)
                        trendingSection(summary.trendingTopics)
                        winningFormulasSection(summary.winningFormulas)
                        whitespaceSection(summary.whitespaceOpportunities)
                        recommendationsSection(summary.recommendations)
                    } else {
                        ProgressView("Generating analysis...")
                    }
                }
                .padding()
            }
            .navigationTitle("Executive Summary")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.loadSampleData()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }

    // MARK: - Overview

    private func overviewSection(_ overview: OverviewMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Overview", icon: "chart.bar.fill")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(title: "Posts Analyzed", value: "\(overview.totalPostsAnalyzed)", icon: "doc.text.fill", color: .blue)
                MetricCard(title: "Creators Tracked", value: "\(overview.totalCreatorsTracked)", icon: "person.3.fill", color: .purple)
                MetricCard(title: "Avg Engagement", value: String(format: "%.2f%%", overview.averageEngagementRate), icon: "heart.fill", color: .pink)
                MetricCard(title: "Top Engagement", value: String(format: "%.2f%%", overview.topEngagementRate), icon: "star.fill", color: .orange)
            }
        }
    }

    // MARK: - Top Creators

    private func topCreatorsSection(_ creators: [CreatorRankingItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Top Creators by Engagement", icon: "person.crop.circle.badge.checkmark")

            ForEach(Array(creators.prefix(5).enumerated()), id: \.element.id) { index, creator in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(creator.displayName)
                            .font(.headline)
                        HStack(spacing: 8) {
                            Label(creator.platform.displayName, systemImage: creator.platform.iconName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(creator.tier)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray5))
                                .clipShape(Capsule())
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f%%", creator.avgEngagementRate))
                            .font(.headline)
                            .foregroundStyle(.blue)
                        Text(formatNumber(creator.followerCount) + " followers")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)

                if index < creators.count - 1 {
                    Divider()
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Fastest Growing

    private func fastestGrowingSection(_ items: [GrowthItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Fastest Growing", icon: "arrow.up.right.circle.fill")

            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack {
                    Text("\(index + 1). \(item.name)")
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.1f%%", item.growthRate) + " growth")
                        .font(.subheadline)
                        .foregroundStyle(item.growthRate >= 0 ? .green : .red)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Top Hashtags

    private func topHashtagsSection(_ items: [HashtagItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Top Hashtags", icon: "number")

            ForEach(items) { item in
                HStack {
                    Text(item.hashtag)
                        .font(.subheadline.bold())
                        .foregroundStyle(.blue)
                    Spacer()
                    Text("\(Int(item.avgEngagement)) avg eng")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("(\(item.postCount) posts)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Trending

    private func trendingSection(_ items: [TrendItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Trending Topics", icon: "flame.fill")

            ForEach(items) { item in
                HStack {
                    Text(item.topic)
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.0f%%", item.growthRate) + " growth")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("(\(item.postCount) posts)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Winning Formulas

    private func winningFormulasSection(_ items: [FormulaItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Winning Content Formulas", icon: "trophy.fill")

            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.formula)
                        .font(.subheadline.bold())
                    Text(String(format: "%.0f%% success rate | %.0f avg engagement", item.successRate, item.avgEngagement))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .cardStyle()
    }

    // MARK: - Whitespace

    private func whitespaceSection(_ items: [WhitespaceItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Whitespace Opportunities", icon: "sparkles")

            ForEach(items) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.topic.capitalized)
                            .font(.subheadline.bold())
                        Text("\(item.creatorCount) creators | Score: \(String(format: "%.0f", item.opportunityScore))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Key Recommendations", icon: "lightbulb.fill")

            ForEach(Array(recs.enumerated()), id: \.offset) { index, rec in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .font(.subheadline.bold())
                        .foregroundStyle(.blue)
                    Text(rec)
                        .font(.subheadline)
                }
            }
        }
        .cardStyle()
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

// MARK: - Reusable Components

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
            Text(title)
                .font(.headline)
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct PriorityBadge: View {
    let priority: String

    var color: Color {
        switch priority {
        case "High": return .red
        case "Medium": return .orange
        default: return .green
        }
    }

    var body: some View {
        Text(priority)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - Card Style Modifier

extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}
