import SwiftUI

struct DiscoveryView: View {
    @EnvironmentObject var viewModel: ResearchViewModel
    @State private var selectedTab = 0
    @State private var nicheInput = ""
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Niche Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search niches (comma-separated)", text: $nicheInput)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            viewModel.nicheSearchText = nicheInput
                            viewModel.refreshNicheDiscovery()
                        }
                    if !nicheInput.isEmpty {
                        Button {
                            nicheInput = ""
                            viewModel.nicheSearchText = ""
                            viewModel.refreshNicheDiscovery()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                .padding(.top, 8)

                Picker("View", selection: $selectedTab) {
                    Text("Top Creators").tag(0)
                    Text("Rising Stars").tag(1)
                    Text("Settings").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                ScrollView {
                    switch selectedTab {
                    case 0: topCreatorsSection
                    case 1: risingStarsSection
                    case 2: settingsSection
                    default: EmptyView()
                    }
                }
            }
            .navigationTitle("Niche Discovery")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.nicheSearchText = nicheInput
                        viewModel.refreshNicheDiscovery()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }

    // MARK: - Top Creators in Niche

    private var topCreatorsSection: some View {
        VStack(spacing: 12) {
            if viewModel.nicheRankings.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Enter niches above to discover top creators")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                Text("\(viewModel.nicheRankings.count) creators found")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(Array(viewModel.nicheRankings.enumerated()), id: \.element.id) { index, creator in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(creator.displayName)
                                    .font(.headline)
                                HStack(spacing: 6) {
                                    Image(systemName: creator.platform.iconName)
                                        .font(.caption)
                                    Text("@\(creator.username)")
                                        .font(.caption)
                                }
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%.1f", creator.compositeScore))
                                    .font(.title3.bold())
                                    .foregroundStyle(.blue)
                                Text(creator.tier)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Score Breakdown
                        HStack(spacing: 16) {
                            MiniScore(label: "Eng", value: creator.engagementScore, color: .pink)
                            MiniScore(label: "Growth", value: creator.growthScore, color: .green)
                            MiniScore(label: "Relevance", value: creator.relevanceScore, color: .blue)
                            MiniScore(label: "Consist.", value: creator.consistencyScore, color: .purple)
                        }

                        // Recommendation
                        Text(creator.recommendation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                    .cardStyle()
                }
            }
        }
        .padding()
    }

    // MARK: - Rising Stars

    private var risingStarsSection: some View {
        VStack(spacing: 12) {
            if viewModel.risingStars.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No rising stars found for current niches")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                Text("Fast-growing creators with high engagement potential")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(viewModel.risingStars) { star in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(star.displayName)
                                    .font(.headline)
                                HStack(spacing: 6) {
                                    Image(systemName: star.platform.iconName)
                                        .font(.caption)
                                    Text("@\(star.username)")
                                        .font(.caption)
                                }
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%.1f", star.starScore))
                                    .font(.title3.bold())
                                    .foregroundStyle(.orange)
                                Text("Star Score")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack(spacing: 16) {
                            VStack {
                                Text(formatNumber(star.followerCount))
                                    .font(.subheadline.bold())
                                Text("Followers")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            VStack {
                                Text(String(format: "%.1f%%", star.growthRate30d))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.green)
                                Text("30d Growth")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            VStack {
                                Text(String(format: "%.1f%%", star.engagementRate))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.pink)
                                Text("Engagement")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)

                        Text(star.potential)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                    .cardStyle()
                }
            }
        }
        .padding()
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Target Niches", icon: "tag.fill")

                Text("Comma-separated niches for analysis")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("e.g., ai, marketing, productivity", text: Binding(
                    get: { viewModel.targetNiches.joined(separator: ", ") },
                    set: { viewModel.updateTargetNiches($0) }
                ))
                .textFieldStyle(.roundedBorder)
            }
            .cardStyle()

            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Ranking Method", icon: "arrow.up.arrow.down")

                Picker("Rank By", selection: $viewModel.rankingMethod) {
                    Text("Composite").tag("composite")
                    Text("Engagement").tag("engagement")
                    Text("Growth").tag("growth")
                    Text("Followers").tag("followers")
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.rankingMethod) { _, _ in
                    viewModel.refreshNicheDiscovery()
                }
            }
            .cardStyle()

            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Platform Filter", icon: "apps.iphone")

                Picker("Platform", selection: $viewModel.selectedPlatformFilter) {
                    Text("All Platforms").tag(SocialPlatform?.none)
                    ForEach(SocialPlatform.allCases.filter { $0 != .other }) { platform in
                        Label(platform.displayName, systemImage: platform.iconName)
                            .tag(SocialPlatform?.some(platform))
                    }
                }
                .onChange(of: viewModel.selectedPlatformFilter) { _, _ in
                    viewModel.refreshNicheDiscovery()
                }
            }
            .cardStyle()

            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Sample Data", icon: "sparkles")

                HStack {
                    Text("Sample size: \(viewModel.sampleSize) creators")
                        .font(.subheadline)
                    Spacer()
                    Stepper("", value: $viewModel.sampleSize, in: 10...100, step: 5)
                        .fixedSize()
                }

                Button {
                    viewModel.loadSampleData()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Regenerate Sample Data")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .cardStyle()

            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Data Import", icon: "square.and.arrow.down")

                Text("Import your own CSV or JSON data files to analyze real influencer data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Supported formats:")
                    .font(.caption.bold())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Posts CSV: post_id, creator_id, platform, text, media_type, timestamp, likes, comments, shares, saves, views, hashtags, topics")
                    Text("Creators CSV: creator_id, username, platform, display_name, follower_count, niche_tags, avg_engagement_rate, growth_rate_7d, growth_rate_30d")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .cardStyle()
        }
        .padding()
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

// MARK: - Mini Score Component

struct MiniScore: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(String(format: "%.0f", value))
                .font(.caption.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
