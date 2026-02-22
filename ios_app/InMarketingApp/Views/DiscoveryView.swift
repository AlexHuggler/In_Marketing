import SwiftUI

struct DiscoveryView: View {
    @EnvironmentObject var viewModel: ResearchViewModel
    @State private var selectedTab = 0
    @State private var nicheInput = ""
    @State private var showSuggestions = false
    @State private var showSettings = false

    var suggestions: [String] {
        guard !nicheInput.isEmpty else { return [] }
        // Get the last typed token (after the last comma)
        let lastToken = nicheInput.split(separator: ",").last.map { String($0).trimmingCharacters(in: .whitespaces) } ?? nicheInput
        guard !lastToken.isEmpty else { return [] }
        return viewModel.nicheSuggestions(for: lastToken)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Niche Search Bar with Autocomplete
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(DS.Colors.secondaryText)
                        TextField("Search niches (comma-separated)", text: $nicheInput)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onSubmit {
                                Haptics.tap()
                                viewModel.nicheSearchText = nicheInput
                                viewModel.refreshNicheDiscovery()
                                showSuggestions = false
                            }
                            .onChange(of: nicheInput) { _, newValue in
                                showSuggestions = !newValue.isEmpty && !suggestions.isEmpty
                            }
                        if !nicheInput.isEmpty {
                            Button {
                                Haptics.tap()
                                nicheInput = ""
                                viewModel.nicheSearchText = ""
                                viewModel.refreshNicheDiscovery()
                                showSuggestions = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(DS.Colors.secondaryText)
                            }
                        }
                    }
                    .padding(DS.Spacing.md)
                    .background(DS.Colors.surfaceBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm + 2))
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.sm)

                    // Autocomplete suggestions
                    if showSuggestions && !suggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DS.Spacing.sm) {
                                ForEach(suggestions, id: \.self) { suggestion in
                                    Button {
                                        Haptics.select()
                                        applySuggestion(suggestion)
                                    } label: {
                                        Text(suggestion)
                                            .font(DS.Typo.caption)
                                            .padding(.horizontal, DS.Spacing.md)
                                            .padding(.vertical, DS.Spacing.sm)
                                            .background(DS.Colors.nicheBlueTint)
                                            .foregroundStyle(DS.Colors.accent)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.vertical, DS.Spacing.sm)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                HStack {
                    Picker("View", selection: $selectedTab) {
                        Text("Top Creators").tag(0)
                        Text("Rising Stars").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedTab) { _, _ in Haptics.select() }

                    Button {
                        Haptics.tap()
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(DS.Colors.secondaryText)
                    }
                }
                .padding(DS.Spacing.lg)

                ScrollView {
                    switch selectedTab {
                    case 0: topCreatorsSection
                    case 1: risingStarsSection
                    default: EmptyView()
                    }
                }
                .refreshable {
                    Haptics.tap()
                    viewModel.nicheSearchText = nicheInput
                    viewModel.refreshNicheDiscovery()
                }
            }
            .navigationTitle("Niche Discovery")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.tap()
                        viewModel.nicheSearchText = nicheInput
                        viewModel.refreshNicheDiscovery()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh discovery")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet()
            }
        }
    }

    private func applySuggestion(_ suggestion: String) {
        // Replace the last token with the suggestion
        var parts = nicheInput.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        if parts.isEmpty {
            nicheInput = suggestion
        } else {
            parts[parts.count - 1] = suggestion
            nicheInput = parts.joined(separator: ", ") + ", "
        }
        showSuggestions = false
    }

    // MARK: - Top Creators in Niche

    private var topCreatorsSection: some View {
        VStack(spacing: DS.Spacing.md) {
            if viewModel.nicheRankings.isEmpty {
                EmptyStateView(
                    icon: "person.3.fill",
                    message: "Enter niches above to discover top creators.\nTry: ai, marketing, productivity",
                    actionLabel: "Search \"ai\"",
                    action: {
                        nicheInput = "ai"
                        viewModel.nicheSearchText = "ai"
                        viewModel.refreshNicheDiscovery()
                    }
                )
            } else {
                Text("\(viewModel.nicheRankings.count) creators found")
                    .font(DS.Typo.caption)
                    .foregroundStyle(DS.Colors.secondaryText)

                ForEach(Array(viewModel.nicheRankings.enumerated()), id: \.element.id) { index, creator in
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        HStack(spacing: DS.Spacing.md) {
                            Text("\(index + 1)")
                                .font(DS.Typo.sectionTitle)
                                .foregroundStyle(DS.Colors.secondaryText)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                Text(creator.displayName)
                                    .font(DS.Typo.cardTitle)
                                HStack(spacing: DS.Spacing.sm) {
                                    Image(systemName: creator.platform.iconName)
                                        .font(DS.Typo.caption)
                                    Text("@\(creator.username)")
                                        .font(DS.Typo.caption)
                                }
                                .foregroundStyle(DS.Colors.secondaryText)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%.1f", creator.compositeScore))
                                    .font(DS.Typo.metric)
                                    .foregroundStyle(DS.Colors.accent)
                                Text(creator.tier)
                                    .font(DS.Typo.badge)
                                    .foregroundStyle(DS.Colors.secondaryText)
                            }
                        }

                        HStack(spacing: DS.Spacing.lg) {
                            MiniScore(label: "Eng", value: creator.engagementScore, color: DS.Colors.engagementPink)
                            MiniScore(label: "Growth", value: creator.growthScore, color: DS.Colors.growthGreen)
                            MiniScore(label: "Relevance", value: creator.relevanceScore, color: DS.Colors.accent)
                            MiniScore(label: "Consist.", value: creator.consistencyScore, color: DS.Colors.info)
                        }

                        Text(creator.recommendation)
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                            .italic()
                    }
                    .cardStyle()
                    .staggeredAppear(index: index)
                }
            }
        }
        .padding(DS.Spacing.lg)
    }

    // MARK: - Rising Stars

    private var risingStarsSection: some View {
        VStack(spacing: DS.Spacing.md) {
            if viewModel.risingStars.isEmpty {
                EmptyStateView(
                    icon: "star.fill",
                    message: "No rising stars found for current niches.\nTry broader search terms or lower growth thresholds."
                )
            } else {
                Text("Fast-growing creators with high engagement potential")
                    .font(DS.Typo.caption)
                    .foregroundStyle(DS.Colors.secondaryText)

                ForEach(Array(viewModel.risingStars.enumerated()), id: \.element.id) { index, star in
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        HStack {
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                Text(star.displayName)
                                    .font(DS.Typo.cardTitle)
                                HStack(spacing: DS.Spacing.sm) {
                                    Image(systemName: star.platform.iconName)
                                        .font(DS.Typo.caption)
                                    Text("@\(star.username)")
                                        .font(DS.Typo.caption)
                                }
                                .foregroundStyle(DS.Colors.secondaryText)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%.1f", star.starScore))
                                    .font(DS.Typo.metric)
                                    .foregroundStyle(DS.Colors.trendOrange)
                                Text("Star Score")
                                    .font(DS.Typo.badge)
                                    .foregroundStyle(DS.Colors.secondaryText)
                            }
                        }

                        HStack(spacing: DS.Spacing.lg) {
                            VStack {
                                Text(formatNumber(star.followerCount))
                                    .font(DS.Typo.bodyBold)
                                Text("Followers")
                                    .font(DS.Typo.badge)
                                    .foregroundStyle(DS.Colors.secondaryText)
                            }
                            VStack {
                                Text(String(format: "%.1f%%", star.growthRate30d))
                                    .font(DS.Typo.bodyBold)
                                    .foregroundStyle(DS.Colors.growthGreen)
                                Text("30d Growth")
                                    .font(DS.Typo.badge)
                                    .foregroundStyle(DS.Colors.secondaryText)
                            }
                            VStack {
                                Text(String(format: "%.1f%%", star.engagementRate))
                                    .font(DS.Typo.bodyBold)
                                    .foregroundStyle(DS.Colors.engagementPink)
                                Text("Engagement")
                                    .font(DS.Typo.badge)
                                    .foregroundStyle(DS.Colors.secondaryText)
                            }
                        }
                        .frame(maxWidth: .infinity)

                        Text(star.potential)
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                            .italic()
                    }
                    .cardStyle()
                    .staggeredAppear(index: index)
                }
            }
        }
        .padding(DS.Spacing.lg)
    }
}

// MARK: - Settings Sheet (extracted from tab to modal)

struct SettingsSheet: View {
    @EnvironmentObject var viewModel: ResearchViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showFileImporter = false
    @State private var importType = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        SectionHeader(title: "Target Niches", icon: "tag.fill")

                        Text("Comma-separated niches for analysis")
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.Colors.secondaryText)

                        TextField("e.g., ai, marketing, productivity", text: Binding(
                            get: { viewModel.targetNiches.joined(separator: ", ") },
                            set: { viewModel.updateTargetNiches($0) }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    }
                    .cardStyle()

                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        SectionHeader(title: "Ranking Method", icon: "arrow.up.arrow.down")

                        Picker("Rank By", selection: $viewModel.rankingMethod) {
                            Text("Composite").tag("composite")
                            Text("Engagement").tag("engagement")
                            Text("Growth").tag("growth")
                            Text("Followers").tag("followers")
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: viewModel.rankingMethod) { _, _ in
                            Haptics.select()
                            viewModel.refreshNicheDiscovery()
                        }
                    }
                    .cardStyle()

                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        SectionHeader(title: "Platform Filter", icon: "apps.iphone")

                        Picker("Platform", selection: $viewModel.selectedPlatformFilter) {
                            Text("All Platforms").tag(SocialPlatform?.none)
                            ForEach(SocialPlatform.allCases.filter { $0 != .other }) { platform in
                                Label(platform.displayName, systemImage: platform.iconName)
                                    .tag(SocialPlatform?.some(platform))
                            }
                        }
                        .onChange(of: viewModel.selectedPlatformFilter) { _, _ in
                            Haptics.select()
                            viewModel.refreshNicheDiscovery()
                        }
                    }
                    .cardStyle()

                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        SectionHeader(title: "Sample Data", icon: "sparkles")

                        HStack {
                            Text("Sample size: \(viewModel.sampleSize) creators")
                                .font(DS.Typo.body)
                            Spacer()
                            Stepper("", value: $viewModel.sampleSize, in: 10...100, step: 5)
                                .fixedSize()
                        }

                        Button {
                            Haptics.tap()
                            viewModel.loadSampleData()
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Regenerate Sample Data")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(DS.Spacing.lg)
                            .background(DS.Colors.accent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm + 2))
                        }
                    }
                    .cardStyle()

                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        SectionHeader(title: "Data Import", icon: "square.and.arrow.down")

                        Text("Import your own CSV or JSON data files to analyze real influencer data.")
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.Colors.secondaryText)

                        HStack(spacing: DS.Spacing.md) {
                            Button {
                                Haptics.select()
                                importType = "posts"
                                showFileImporter = true
                            } label: {
                                HStack {
                                    Image(systemName: "doc.badge.plus")
                                    Text("Posts CSV")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(DS.Spacing.md)
                                .background(DS.Colors.surfaceBackground)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                            }

                            Button {
                                Haptics.select()
                                importType = "creators"
                                showFileImporter = true
                            } label: {
                                HStack {
                                    Image(systemName: "person.badge.plus")
                                    Text("Creators CSV")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(DS.Spacing.md)
                                .background(DS.Colors.surfaceBackground)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                            }
                        }

                        Text("Supported columns:")
                            .font(DS.Typo.captionBold)
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text("Posts: post_id, creator_id, platform, text, media_type, timestamp, likes, comments, shares, saves, views, hashtags, topics")
                            Text("Creators: creator_id, username, platform, display_name, follower_count, niche_tags, avg_engagement_rate, growth_rate_7d, growth_rate_30d")
                        }
                        .font(DS.Typo.badge)
                        .foregroundStyle(DS.Colors.tertiaryText)
                    }
                    .cardStyle()

                    // Export
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        SectionHeader(title: "Export Data", icon: "square.and.arrow.up")

                        if let jsonData = viewModel.exportJSON(), let jsonString = String(data: jsonData, encoding: .utf8) {
                            ShareLink(item: jsonString) {
                                HStack {
                                    Image(systemName: "doc.text")
                                    Text("Export as JSON")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(DS.Spacing.md)
                                .background(DS.Colors.surfaceBackground)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                            }
                        }
                    }
                    .cardStyle()
                }
                .padding(DS.Spacing.lg)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        Haptics.tap()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.commaSeparatedText, .json]) { result in
                if case .success(let url) = result {
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }

                    if let content = try? String(contentsOf: url, encoding: .utf8) {
                        if url.pathExtension == "json", let data = content.data(using: .utf8) {
                            viewModel.loadJSON(data: data)
                        } else if importType == "posts" {
                            viewModel.loadPostsCSV(content: content)
                        } else {
                            viewModel.loadCreatorsCSV(content: content)
                        }
                    }
                }
            }
        }
    }
}
