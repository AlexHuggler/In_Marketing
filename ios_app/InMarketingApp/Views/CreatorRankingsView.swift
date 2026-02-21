import SwiftUI

struct CreatorRankingsView: View {
    @EnvironmentObject var viewModel: ResearchViewModel
    @State private var searchText = ""
    @State private var sortBy = "composite"
    @State private var selectedCreator: CreatorRankingItem?

    var filteredRankings: [CreatorRankingItem] {
        let rankings = viewModel.creatorRankings
        if searchText.isEmpty { return rankings }
        return rankings.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.username.localizedCaseInsensitiveContains(searchText) ||
            $0.allNiches.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        StatPill(label: "Total", value: "\(viewModel.creators.count)", color: .blue)
                        StatPill(label: "Avg Eng", value: String(format: "%.1f%%", viewModel.averageEngagementRate), color: .pink)
                        StatPill(label: "Posts", value: "\(viewModel.posts.count)", color: .purple)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 4)
                }

                Section("Ranked by Composite Score") {
                    ForEach(Array(filteredRankings.enumerated()), id: \.element.id) { index, ranking in
                        NavigationLink {
                            CreatorDetailView(ranking: ranking)
                        } label: {
                            CreatorRankingRow(rank: index + 1, ranking: ranking)
                        }
                    }
                }
            }
            .navigationTitle("Creator Rankings")
            .searchable(text: $searchText, prompt: "Search creators or niches")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Composite Score") { sortBy = "composite" }
                        Button("Engagement Rate") { sortBy = "engagement" }
                        Button("Growth Rate") { sortBy = "growth" }
                        Button("Followers") { sortBy = "followers" }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
        }
    }
}

// MARK: - Creator Ranking Row

struct CreatorRankingRow: View {
    let rank: Int
    let ranking: CreatorRankingItem

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text(ranking.displayName)
                    .font(.headline)

                HStack(spacing: 6) {
                    Image(systemName: ranking.platform.iconName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("@\(ranking.username)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Text(ranking.tier)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())

                    Text(ranking.primaryNiche)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.1f", ranking.compositeScore))
                    .font(.title3.bold())
                    .foregroundStyle(.blue)

                Text(String(format: "%.1f%% eng", ranking.avgEngagementRate))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(formatFollowers(ranking.followerCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatFollowers(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

// MARK: - Creator Detail View

struct CreatorDetailView: View {
    let ranking: CreatorRankingItem
    @EnvironmentObject var viewModel: ResearchViewModel

    var creatorPosts: [Post] {
        viewModel.posts(for: ranking.creatorId)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue)
                    Text(ranking.displayName)
                        .font(.title.bold())
                    Text("@\(ranking.username)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Label(ranking.platform.displayName, systemImage: ranking.platform.iconName)
                        Text(ranking.tier)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                    }
                    .font(.subheadline)
                }
                .padding()

                // Metrics Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    MetricTile(title: "Followers", value: formatNumber(ranking.followerCount))
                    MetricTile(title: "Engagement", value: String(format: "%.2f%%", ranking.avgEngagementRate))
                    MetricTile(title: "Composite", value: String(format: "%.1f", ranking.compositeScore))
                    MetricTile(title: "Growth 7d", value: String(format: "%.1f%%", ranking.growthRate7d))
                    MetricTile(title: "Growth 30d", value: String(format: "%.1f%%", ranking.growthRate30d))
                    MetricTile(title: "Best Eng", value: String(format: "%.2f%%", ranking.bestEngagementRate))
                }
                .padding(.horizontal)

                // Quality Scores
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Quality Scores", icon: "checkmark.seal.fill")

                    ScoreBar(label: "Consistency", score: ranking.consistencyScore)
                    ScoreBar(label: "Authenticity", score: ranking.authenticityScore)
                    ScoreBar(label: "Community", score: ranking.communityScore)
                    ScoreBar(label: "Comment Quality", score: ranking.commentQuality)
                }
                .cardStyle()
                .padding(.horizontal)

                // Niches
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Niches", icon: "tag.fill")
                    FlowLayout(items: ranking.allNiches.split(separator: ",").map(String.init)) { niche in
                        Text(niche.trimmingCharacters(in: .whitespaces))
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
                .cardStyle()
                .padding(.horizontal)

                // Recent Posts
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Recent Posts (\(creatorPosts.count))", icon: "doc.text.fill")

                    ForEach(creatorPosts.sorted(by: { $0.timestamp > $1.timestamp }).prefix(10)) { post in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(post.text)
                                .font(.subheadline)
                                .lineLimit(3)

                            HStack(spacing: 12) {
                                Label("\(post.metrics.likes)", systemImage: "heart.fill")
                                Label("\(post.metrics.comments)", systemImage: "bubble.left.fill")
                                Label("\(post.metrics.shares)", systemImage: "arrow.turn.up.right")
                                Spacer()
                                Text(post.timestamp, style: .relative)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                        Divider()
                    }
                }
                .cardStyle()
                .padding(.horizontal)
            }
        }
        .navigationTitle(ranking.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

// MARK: - Support Views

struct MetricTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct ScoreBar: View {
    let label: String
    let score: Double

    var color: Color {
        if score >= 70 { return .green }
        if score >= 40 { return .orange }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.0f", score))
                    .font(.subheadline.bold())
                    .foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * min(score / 100.0, 1.0))
                }
            }
            .frame(height: 8)
        }
    }
}

struct StatPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct FlowLayout<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
            ForEach(items, id: \.self) { item in
                content(item)
            }
        }
    }
}
