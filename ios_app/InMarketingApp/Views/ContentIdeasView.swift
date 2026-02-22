import SwiftUI

struct ContentIdeasView: View {
    @EnvironmentObject var viewModel: ResearchViewModel
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $selectedTab) {
                    Text("Formulas").tag(0)
                    Text("Whitespace").tag(1)
                    Text("Collaborations").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(DS.Spacing.lg)
                .onChange(of: selectedTab) { _, _ in Haptics.select() }

                ScrollView {
                    switch selectedTab {
                    case 0: contentFormulasSection
                    case 1: whitespaceSection
                    case 2: collaborationSection
                    default: EmptyView()
                    }
                }
                .refreshable {
                    Haptics.tap()
                    viewModel.generateAllReports()
                }
            }
            .navigationTitle("Content Ideas")
        }
    }

    // MARK: - Content Formulas

    private var contentFormulasSection: some View {
        VStack(spacing: DS.Spacing.lg) {
            let formulas = viewModel.contentIdeas.filter { !$0.isWhitespaceOpportunity }

            if formulas.isEmpty {
                EmptyStateView(
                    icon: "lightbulb",
                    message: "No content formulas detected yet.\nImport more posts to identify winning patterns.",
                    actionLabel: "Load Sample Data",
                    action: { viewModel.loadSampleData() }
                )
            } else {
                ForEach(Array(formulas.enumerated()), id: \.element.id) { index, idea in
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(DS.Colors.trendOrange)
                            Text(idea.formulaName)
                                .font(DS.Typo.cardTitle)
                            Spacer()
                            Text(String(format: "%.0f%% success", idea.successRate))
                                .font(DS.Typo.captionBold)
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, DS.Spacing.xs)
                                .background(idea.successRate >= 50 ? DS.Colors.success.opacity(0.15) : DS.Colors.warning.opacity(0.15))
                                .foregroundStyle(idea.successRate >= 50 ? DS.Colors.success : DS.Colors.warning)
                                .clipShape(Capsule())
                        }

                        Text(idea.description)
                            .font(DS.Typo.body)
                            .foregroundStyle(DS.Colors.secondaryText)

                        HStack(spacing: DS.Spacing.lg) {
                            Label(idea.hookType, systemImage: "quote.bubble.fill")
                            Label(idea.format, systemImage: "doc.text.fill")
                            Label("\(idea.postsUsingFormula) posts", systemImage: "number")
                        }
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.Colors.secondaryText)

                        if !idea.template.isEmpty {
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                Text("Template:")
                                    .font(DS.Typo.captionBold)
                                    .foregroundStyle(DS.Colors.accent)
                                Text(idea.template)
                                    .font(DS.Typo.caption)
                                    .padding(DS.Spacing.md)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(DS.Colors.surfaceBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                            }
                        }

                        if !idea.themes.isEmpty {
                            HStack {
                                ForEach(idea.themes, id: \.self) { theme in
                                    Text(theme)
                                        .font(DS.Typo.badge)
                                        .padding(.horizontal, DS.Spacing.sm)
                                        .padding(.vertical, DS.Spacing.xs)
                                        .background(DS.Colors.nicheBlueTint)
                                        .foregroundStyle(DS.Colors.accent)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .cardStyle()
                    .staggeredAppear(index: index)
                }
            }
        }
        .padding(DS.Spacing.lg)
    }

    // MARK: - Whitespace Opportunities

    private var whitespaceSection: some View {
        VStack(spacing: DS.Spacing.lg) {
            if viewModel.whitespaceOpportunities.isEmpty {
                EmptyStateView(
                    icon: "sparkles",
                    message: "No whitespace opportunities found.\nTry adjusting your target niches in Settings.",
                    actionLabel: "Go to Settings",
                    action: { /* Tab switch handled by parent */ }
                )
            } else {
                ForEach(Array(viewModel.whitespaceOpportunities.enumerated()), id: \.element.id) { index, opp in
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        HStack {
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                Text(opp.topic.capitalized)
                                    .font(DS.Typo.cardTitle)
                                Text(opp.niche)
                                    .font(DS.Typo.caption)
                                    .foregroundStyle(DS.Colors.secondaryText)
                            }
                            Spacer()
                            PriorityBadge(priority: opp.recommendedPriority)
                        }

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.sm) {
                            VStack {
                                Text(String(format: "%.0f", opp.opportunityScore))
                                    .font(DS.Typo.sectionTitle)
                                    .foregroundStyle(DS.Colors.accent)
                                Text("Score")
                                    .font(DS.Typo.badge)
                                    .foregroundStyle(DS.Colors.secondaryText)
                            }
                            VStack {
                                Text("\(opp.creatorCount)")
                                    .font(DS.Typo.sectionTitle)
                                    .foregroundStyle(DS.Colors.success)
                                Text("Creators")
                                    .font(DS.Typo.badge)
                                    .foregroundStyle(DS.Colors.secondaryText)
                            }
                            VStack {
                                Text(String(format: "%.0f", opp.engagementRate))
                                    .font(DS.Typo.sectionTitle)
                                    .foregroundStyle(DS.Colors.trendOrange)
                                Text("Avg Eng")
                                    .font(DS.Typo.badge)
                                    .foregroundStyle(DS.Colors.secondaryText)
                            }
                        }

                        if !opp.exampleAngles.isEmpty {
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                Text("Suggested Angles:")
                                    .font(DS.Typo.captionBold)
                                ForEach(opp.exampleAngles, id: \.self) { angle in
                                    HStack(alignment: .top, spacing: DS.Spacing.sm) {
                                        Image(systemName: "arrow.right.circle.fill")
                                            .font(DS.Typo.caption)
                                            .foregroundStyle(DS.Colors.accent)
                                        Text(angle)
                                            .font(DS.Typo.caption)
                                    }
                                }
                            }
                        }
                    }
                    .cardStyle()
                    .staggeredAppear(index: index)
                }
            }
        }
        .padding(DS.Spacing.lg)
    }

    // MARK: - Collaboration Targets

    private var collaborationSection: some View {
        VStack(spacing: DS.Spacing.md) {
            if viewModel.collaborationTargets.isEmpty {
                EmptyStateView(
                    icon: "person.2.fill",
                    message: "No collaboration targets found.\nSet target niches in Discovery > Settings to find aligned creators.",
                    actionLabel: "Load Sample Data",
                    action: { viewModel.loadSampleData() }
                )
            } else {
                ForEach(Array(viewModel.collaborationTargets.enumerated()), id: \.element.id) { index, target in
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(target.name)
                                    .font(DS.Typo.cardTitle)
                                Label(target.platform.displayName, systemImage: target.platform.iconName)
                                    .font(DS.Typo.caption)
                                    .foregroundStyle(DS.Colors.secondaryText)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%.0f", target.overallFitScore))
                                    .font(DS.Typo.metric)
                                    .foregroundStyle(DS.Colors.accent)
                                Text("Fit Score")
                                    .font(DS.Typo.badge)
                                    .foregroundStyle(DS.Colors.secondaryText)
                            }
                        }

                        HStack(spacing: DS.Spacing.lg) {
                            VStack {
                                Text(formatNumber(target.followers))
                                    .font(DS.Typo.bodyBold)
                                Text("Followers")
                                    .font(DS.Typo.badge)
                                    .foregroundStyle(DS.Colors.secondaryText)
                            }
                            VStack {
                                Text(String(format: "%.1f%%", target.engagementRate))
                                    .font(DS.Typo.bodyBold)
                                Text("Engagement")
                                    .font(DS.Typo.badge)
                                    .foregroundStyle(DS.Colors.secondaryText)
                            }
                            VStack {
                                Text(String(format: "%.1f%%", target.growthRate))
                                    .font(DS.Typo.bodyBold)
                                Text("Growth")
                                    .font(DS.Typo.badge)
                                    .foregroundStyle(DS.Colors.secondaryText)
                            }
                            VStack {
                                Text(String(format: "%.0f", target.nicheAlignmentScore))
                                    .font(DS.Typo.bodyBold)
                                Text("Alignment")
                                    .font(DS.Typo.badge)
                                    .foregroundStyle(DS.Colors.secondaryText)
                            }
                        }
                        .frame(maxWidth: .infinity)

                        Text(target.recommendation)
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
