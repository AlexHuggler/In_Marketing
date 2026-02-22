import SwiftUI
import Combine

struct CreatorRankingsView: View {
    @EnvironmentObject var viewModel: ResearchViewModel
    @State private var searchText = ""
    @State private var debouncedSearch = ""
    @State private var sortBy = "composite"
    @State private var showFavoritesOnly = false

    // Debounce search to avoid O(n) on every keystroke
    @State private var searchTask: Task<Void, Never>?

    var filteredRankings: [CreatorRankingItem] {
        var rankings = viewModel.creatorRankings

        if showFavoritesOnly {
            rankings = rankings.filter { viewModel.isFavorited($0.creatorId) }
        }

        guard !debouncedSearch.isEmpty else { return rankings }
        let query = debouncedSearch.lowercased()
        return rankings.filter {
            $0.displayName.lowercased().contains(query) ||
            $0.username.lowercased().contains(query) ||
            $0.allNiches.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: DS.Spacing.md) {
                        StatPill(label: "Total", value: "\(viewModel.creators.count)", color: DS.Colors.accent)
                        StatPill(label: "Avg Eng", value: String(format: "%.1f%%", viewModel.averageEngagementRate), color: DS.Colors.engagementPink)
                        StatPill(label: "Posts", value: "\(viewModel.posts.count)", color: DS.Colors.info)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, DS.Spacing.xs)
                }

                if !viewModel.favoritedCreatorIds.isEmpty {
                    Section {
                        Button {
                            Haptics.select()
                            withAnimation(DS.Animation.quick) {
                                showFavoritesOnly.toggle()
                            }
                        } label: {
                            HStack {
                                Image(systemName: showFavoritesOnly ? "star.fill" : "star")
                                    .foregroundStyle(DS.Colors.trendOrange)
                                Text(showFavoritesOnly ? "Showing Favorites (\(viewModel.favoritedCreatorIds.count))" : "Show Favorites Only")
                                    .font(DS.Typo.body)
                                Spacer()
                                if showFavoritesOnly {
                                    Text("Show All")
                                        .font(DS.Typo.caption)
                                        .foregroundStyle(DS.Colors.accent)
                                }
                            }
                        }
                    }
                }

                Section("Ranked by \(sortLabel)") {
                    ForEach(Array(filteredRankings.enumerated()), id: \.element.id) { index, ranking in
                        NavigationLink {
                            CreatorDetailView(ranking: ranking)
                        } label: {
                            CreatorRankingRow(
                                rank: index + 1,
                                ranking: ranking,
                                isFavorited: viewModel.isFavorited(ranking.creatorId)
                            )
                        }
                        .swipeActions(edge: .trailing) {
                            Button {
                                viewModel.toggleFavorite(creatorId: ranking.creatorId)
                            } label: {
                                Label(
                                    viewModel.isFavorited(ranking.creatorId) ? "Unfavorite" : "Favorite",
                                    systemImage: viewModel.isFavorited(ranking.creatorId) ? "star.slash" : "star.fill"
                                )
                            }
                            .tint(DS.Colors.trendOrange)
                        }
                        .staggeredAppear(index: index)
                    }
                }
            }
            .navigationTitle("Creator Rankings")
            .searchable(text: $searchText, prompt: "Search creators or niches")
            .onChange(of: searchText) { _, newValue in
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 250_000_000) // 250ms debounce
                    guard !Task.isCancelled else { return }
                    debouncedSearch = newValue
                }
            }
            .refreshable {
                Haptics.tap()
                viewModel.generateAllReports()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { updateSort("composite") } label: {
                            Label("Composite Score", systemImage: sortBy == "composite" ? "checkmark" : "")
                        }
                        Button { updateSort("engagement") } label: {
                            Label("Engagement Rate", systemImage: sortBy == "engagement" ? "checkmark" : "")
                        }
                        Button { updateSort("growth") } label: {
                            Label("Growth Rate", systemImage: sortBy == "growth" ? "checkmark" : "")
                        }
                        Button { updateSort("followers") } label: {
                            Label("Followers", systemImage: sortBy == "followers" ? "checkmark" : "")
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .accessibilityLabel("Sort creators")
                }
            }
        }
    }

    private var sortLabel: String {
        switch sortBy {
        case "engagement": return "Engagement Rate"
        case "growth": return "Growth Rate"
        case "followers": return "Followers"
        default: return "Composite Score"
        }
    }

    private func updateSort(_ method: String) {
        Haptics.select()
        sortBy = method
    }
}

// MARK: - Creator Ranking Row

struct CreatorRankingRow: View {
    let rank: Int
    let ranking: CreatorRankingItem
    let isFavorited: Bool

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                Text("\(rank)")
                    .font(DS.Typo.sectionTitle)
                    .foregroundStyle(DS.Colors.secondaryText)
                if isFavorited {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(DS.Colors.trendOrange)
                        .offset(x: 10, y: -8)
                }
            }
            .frame(width: 28, alignment: .center)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(ranking.displayName)
                    .font(DS.Typo.cardTitle)

                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: ranking.platform.iconName)
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                    Text("@\(ranking.username)")
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                }

                HStack(spacing: DS.Spacing.sm) {
                    Text(ranking.tier)
                        .font(DS.Typo.badge)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DS.Colors.surfaceBackground)
                        .clipShape(Capsule())

                    Text(ranking.primaryNiche)
                        .font(DS.Typo.badge)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DS.Colors.nicheBlueTint)
                        .foregroundStyle(DS.Colors.accent)
                        .clipShape(Capsule())
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                Text(String(format: "%.1f", ranking.compositeScore))
                    .font(DS.Typo.metric)
                    .foregroundStyle(DS.Colors.accent)
                    .contentTransition(.numericText(value: ranking.compositeScore))

                Text(String(format: "%.1f%% eng", ranking.avgEngagementRate))
                    .font(DS.Typo.caption)
                    .foregroundStyle(DS.Colors.secondaryText)

                Text(formatNumber(ranking.followerCount))
                    .font(DS.Typo.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}

// MARK: - Creator Detail View

struct CreatorDetailView: View {
    let ranking: CreatorRankingItem
    @EnvironmentObject var viewModel: ResearchViewModel

    var creatorPosts: [Post] {
        viewModel.posts(for: ranking.creatorId)
    }

    var shareText: String {
        """
        \(ranking.displayName) (@\(ranking.username))
        Platform: \(ranking.platform.displayName)
        Followers: \(formatNumber(ranking.followerCount))
        Engagement: \(String(format: "%.2f%%", ranking.avgEngagementRate))
        Growth (30d): \(String(format: "%.1f%%", ranking.growthRate30d))
        Niches: \(ranking.allNiches)
        Composite Score: \(String(format: "%.1f", ranking.compositeScore))
        """
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xl) {
                // Header
                VStack(spacing: DS.Spacing.sm) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(DS.Colors.accent)

                        Button {
                            viewModel.toggleFavorite(creatorId: ranking.creatorId)
                        } label: {
                            Image(systemName: viewModel.isFavorited(ranking.creatorId) ? "star.fill" : "star")
                                .font(.title3)
                                .foregroundStyle(viewModel.isFavorited(ranking.creatorId) ? DS.Colors.trendOrange : DS.Colors.tertiaryText)
                        }
                        .offset(x: 30, y: -4)
                    }

                    Text(ranking.displayName)
                        .font(.title.bold())
                    Text("@\(ranking.username)")
                        .font(DS.Typo.body)
                        .foregroundStyle(DS.Colors.secondaryText)

                    HStack(spacing: DS.Spacing.md) {
                        Label(ranking.platform.displayName, systemImage: ranking.platform.iconName)
                        Text(ranking.tier)
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, DS.Spacing.xs)
                            .background(DS.Colors.surfaceBackground)
                            .clipShape(Capsule())
                    }
                    .font(DS.Typo.body)
                }
                .padding()
                .staggeredAppear(index: 0)

                // Metrics Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.md) {
                    MetricTile(title: "Followers", value: formatNumber(ranking.followerCount))
                    MetricTile(title: "Engagement", value: String(format: "%.2f%%", ranking.avgEngagementRate))
                    MetricTile(title: "Composite", value: String(format: "%.1f", ranking.compositeScore))
                    MetricTile(title: "Growth 7d", value: String(format: "%.1f%%", ranking.growthRate7d))
                    MetricTile(title: "Growth 30d", value: String(format: "%.1f%%", ranking.growthRate30d))
                    MetricTile(title: "Best Eng", value: String(format: "%.2f%%", ranking.bestEngagementRate))
                }
                .padding(.horizontal)
                .staggeredAppear(index: 1)

                // Quality Scores
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    SectionHeader(title: "Quality Scores", icon: "checkmark.seal.fill")
                    ScoreBar(label: "Consistency", score: ranking.consistencyScore)
                    ScoreBar(label: "Authenticity", score: ranking.authenticityScore)
                    ScoreBar(label: "Community", score: ranking.communityScore)
                    ScoreBar(label: "Comment Quality", score: ranking.commentQuality)
                }
                .cardStyle()
                .padding(.horizontal)
                .staggeredAppear(index: 2)

                // Niches
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    SectionHeader(title: "Niches", icon: "tag.fill")
                    FlowLayout(items: ranking.allNiches.split(separator: ",").map(String.init)) { niche in
                        Text(niche.trimmingCharacters(in: .whitespaces))
                            .font(DS.Typo.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(DS.Colors.nicheBlueTint)
                            .foregroundStyle(DS.Colors.accent)
                            .clipShape(Capsule())
                    }
                }
                .cardStyle()
                .padding(.horizontal)
                .staggeredAppear(index: 3)

                // Recent Posts
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    SectionHeader(title: "Recent Posts (\(creatorPosts.count))", icon: "doc.text.fill")

                    ForEach(creatorPosts.sorted(by: { $0.timestamp > $1.timestamp }).prefix(10)) { post in
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Text(post.text)
                                .font(DS.Typo.body)
                                .lineLimit(3)

                            HStack(spacing: DS.Spacing.md) {
                                Label("\(post.metrics.likes)", systemImage: "heart.fill")
                                Label("\(post.metrics.comments)", systemImage: "bubble.left.fill")
                                Label("\(post.metrics.shares)", systemImage: "arrow.turn.up.right")
                                Spacer()
                                Text(post.timestamp, style: .relative)
                            }
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                        }
                        .padding(.vertical, DS.Spacing.sm)
                        Divider()
                    }
                }
                .cardStyle()
                .padding(.horizontal)
                .staggeredAppear(index: 4)
            }
        }
        .navigationTitle(ranking.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share creator profile")
            }
        }
    }
}
