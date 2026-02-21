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
                .padding()

                ScrollView {
                    switch selectedTab {
                    case 0: contentFormulasSection
                    case 1: whitespaceSection
                    case 2: collaborationSection
                    default: EmptyView()
                    }
                }
            }
            .navigationTitle("Content Ideas")
        }
    }

    // MARK: - Content Formulas

    private var contentFormulasSection: some View {
        VStack(spacing: 16) {
            let formulas = viewModel.contentIdeas.filter { !$0.isWhitespaceOpportunity }

            if formulas.isEmpty {
                emptyState(icon: "lightbulb", message: "No content formulas detected yet")
            } else {
                ForEach(formulas) { idea in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.orange)
                            Text(idea.formulaName)
                                .font(.headline)
                            Spacer()
                            Text(String(format: "%.0f%% success", idea.successRate))
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(idea.successRate >= 50 ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                                .foregroundStyle(idea.successRate >= 50 ? .green : .orange)
                                .clipShape(Capsule())
                        }

                        Text(idea.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 16) {
                            Label(idea.hookType, systemImage: "quote.bubble.fill")
                            Label(idea.format, systemImage: "doc.text.fill")
                            Label("\(idea.postsUsingFormula) posts", systemImage: "number")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        // Template
                        if !idea.template.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Template:")
                                    .font(.caption.bold())
                                    .foregroundStyle(.blue)
                                Text(idea.template)
                                    .font(.caption)
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }

                        if !idea.themes.isEmpty {
                            HStack {
                                ForEach(idea.themes, id: \.self) { theme in
                                    Text(theme)
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundStyle(.blue)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .cardStyle()
                }
            }
        }
        .padding()
    }

    // MARK: - Whitespace Opportunities

    private var whitespaceSection: some View {
        VStack(spacing: 16) {
            if viewModel.whitespaceOpportunities.isEmpty {
                emptyState(icon: "sparkles", message: "No whitespace opportunities found")
            } else {
                ForEach(viewModel.whitespaceOpportunities) { opp in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(opp.topic.capitalized)
                                    .font(.headline)
                                Text(opp.niche)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            PriorityBadge(priority: opp.recommendedPriority)
                        }

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            VStack {
                                Text(String(format: "%.0f", opp.opportunityScore))
                                    .font(.headline)
                                    .foregroundStyle(.blue)
                                Text("Score")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            VStack {
                                Text("\(opp.creatorCount)")
                                    .font(.headline)
                                    .foregroundStyle(.green)
                                Text("Creators")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            VStack {
                                Text(String(format: "%.0f", opp.engagementRate))
                                    .font(.headline)
                                    .foregroundStyle(.orange)
                                Text("Avg Eng")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if !opp.exampleAngles.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Suggested Angles:")
                                    .font(.caption.bold())
                                ForEach(opp.exampleAngles, id: \.self) { angle in
                                    HStack(alignment: .top, spacing: 6) {
                                        Image(systemName: "arrow.right.circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                        Text(angle)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                    }
                    .cardStyle()
                }
            }
        }
        .padding()
    }

    // MARK: - Collaboration Targets

    private var collaborationSection: some View {
        VStack(spacing: 12) {
            if viewModel.collaborationTargets.isEmpty {
                emptyState(icon: "person.2.fill", message: "No collaboration targets found")
            } else {
                ForEach(viewModel.collaborationTargets) { target in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(target.name)
                                    .font(.headline)
                                Label(target.platform.displayName, systemImage: target.platform.iconName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%.0f", target.overallFitScore))
                                    .font(.title3.bold())
                                    .foregroundStyle(.blue)
                                Text("Fit Score")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack(spacing: 16) {
                            VStack {
                                Text(formatNumber(target.followers))
                                    .font(.subheadline.bold())
                                Text("Followers")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            VStack {
                                Text(String(format: "%.1f%%", target.engagementRate))
                                    .font(.subheadline.bold())
                                Text("Engagement")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            VStack {
                                Text(String(format: "%.1f%%", target.growthRate))
                                    .font(.subheadline.bold())
                                Text("Growth")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            VStack {
                                Text(String(format: "%.0f", target.nicheAlignmentScore))
                                    .font(.subheadline.bold())
                                Text("Alignment")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)

                        Text(target.recommendation)
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

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}
