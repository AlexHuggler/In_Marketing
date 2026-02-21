import Foundation

/// Generates comprehensive reports for actionable decision-making.
struct ReportGenerator {
    let posts: [Post]
    let creators: [String: Creator]
    let targetNiches: [String]

    private var engagementAnalyzer: EngagementAnalyzer {
        EngagementAnalyzer(posts: posts, creators: creators)
    }
    private var trendAnalyzer: TrendAnalyzer {
        var t = TrendAnalyzer(posts: posts)
        t.engagementAnalyzer = engagementAnalyzer
        return t
    }
    private var patternAnalyzer: ContentPatternAnalyzer {
        ContentPatternAnalyzer(posts: posts)
    }
    private var whitespaceAnalyzer: WhitespaceAnalyzer {
        WhitespaceAnalyzer(posts: posts, creators: creators)
    }
    private var qualityAnalyzer: EngagementQualityAnalyzer {
        EngagementQualityAnalyzer(posts: posts)
    }
    private var collabAnalyzer: CollaborationAnalyzer? {
        targetNiches.isEmpty ? nil : CollaborationAnalyzer(creators: creators, targetNiches: targetNiches)
    }

    // MARK: - Executive Summary

    func generateExecutiveSummary() -> ExecutiveSummary {
        let analyzer = engagementAnalyzer
        let engagementRates = posts.map { analyzer.calculateEngagementRate(for: $0) }
        let avgEngagement = engagementRates.mean
        let topEngagement = engagementRates.max() ?? 0

        let topCreators = analyzer.rankCreatorsByEngagement().prefix(5).map { c, m in
            CreatorRankingItem(
                creatorId: c.id, username: c.username,
                displayName: c.displayName.isEmpty ? c.username : c.displayName,
                platform: c.platform, tier: c.tier,
                followerCount: c.followerCount,
                primaryNiche: c.primaryNiche,
                allNiches: c.nicheTags.joined(separator: ", "),
                avgEngagementRate: m.avgEngagementRate,
                bestEngagementRate: m.bestEngagementRate,
                consistencyScore: m.consistencyScore,
                growthRate7d: c.followerGrowthRate7d,
                growthRate30d: c.followerGrowthRate30d,
                authenticityScore: 0, communityScore: 0,
                commentQuality: 0, compositeScore: 0, postsAnalyzed: m.totalPosts
            )
        }

        let fastestGrowing = analyzer.identifyFastestGrowing().prefix(5).map { c, g in
            GrowthItem(name: c.displayName.isEmpty ? c.username : c.displayName,
                       growthRate: g, followers: c.followerCount)
        }

        let topHashtags = Array(trendAnalyzer.analyzeHashtagPerformance().prefix(5))
        let trending = trendAnalyzer.identifyTrendingTopics().prefix(5).map { t in
            TrendItem(topic: t.topic, growthRate: t.growthRate,
                      postCount: t.postCount, avgEngagement: t.avgEngagementRate)
        }

        let formulas = patternAnalyzer.identifyWinningFormulas().prefix(3).map { f in
            FormulaItem(formula: f.name, description: f.formulaDescription,
                        successRate: f.successRate, avgEngagement: f.avgEngagementRate)
        }

        let whitespace = whitespaceAnalyzer.identifyWhitespaceOpportunities().prefix(3).map { w in
            WhitespaceItem(topic: w.topic, opportunityScore: w.opportunityScore,
                           creatorCount: w.creatorCount, priority: w.recommendedPriority)
        }

        return ExecutiveSummary(
            reportDate: Date(),
            overview: OverviewMetrics(
                totalPostsAnalyzed: posts.count,
                totalCreatorsTracked: creators.count,
                averageEngagementRate: avgEngagement,
                topEngagementRate: topEngagement
            ),
            topCreators: Array(topCreators),
            fastestGrowing: Array(fastestGrowing),
            topHashtags: Array(topHashtags),
            trendingTopics: Array(trending),
            winningFormulas: Array(formulas),
            whitespaceOpportunities: Array(whitespace),
            recommendations: generateRecommendations()
        )
    }

    // MARK: - Recommendations

    private func generateRecommendations() -> [String] {
        var recs: [String] = []

        let timing = trendAnalyzer.analyzeTimingPerformance()
        if let bestDay = timing.bestDays.first {
            recs.append("Post on \(bestDay.label)s for highest engagement (\(Int(bestDay.avgEngagement)) avg)")
        }
        if let bestHour = timing.bestHours.first {
            recs.append("Best posting time: \(bestHour.label) (\(Int(bestHour.avgEngagement)) avg engagement)")
        }

        let patterns = patternAnalyzer.analyzePatternPerformance()
        if let bestHook = patterns.hooks.first {
            recs.append("Use '\(bestHook.name)' hooks for best results (\(Int(bestHook.avgEngagement)) avg engagement)")
        }

        let whitespace = whitespaceAnalyzer.identifyWhitespaceOpportunities()
        if let topOpp = whitespace.first {
            recs.append("Consider creating content about '\(topOpp.topic)' - high engagement (\(Int(topOpp.engagementRate))) with only \(topOpp.creatorCount) creators covering it")
        }

        let hashtags = trendAnalyzer.analyzeHashtagPerformance()
        if !hashtags.isEmpty {
            let top3 = hashtags.prefix(3).map(\.hashtag)
            recs.append("Use high-performing hashtags: \(top3.joined(separator: ", "))")
        }

        return recs
    }

    // MARK: - Creator Rankings Report

    func generateCreatorRankings() -> [CreatorRankingItem] {
        let analyzer = engagementAnalyzer
        let quality = qualityAnalyzer

        return creators.values.map { creator in
            let metrics = analyzer.calculateCreatorMetrics(for: creator)
            let qual = quality.analyzeCreatorEngagementQuality(creatorId: creator.id)

            let compositeScore =
                metrics.avgEngagementRate * 10.0 +
                qual.avgAuthenticity * 0.3 +
                qual.communityScore * 0.2 +
                min(creator.followerGrowthRate30d, 50.0) * 0.5

            return CreatorRankingItem(
                creatorId: creator.id, username: creator.username,
                displayName: creator.displayName.isEmpty ? creator.username : creator.displayName,
                platform: creator.platform, tier: creator.tier,
                followerCount: creator.followerCount,
                primaryNiche: creator.primaryNiche,
                allNiches: creator.nicheTags.joined(separator: ", "),
                avgEngagementRate: metrics.avgEngagementRate,
                bestEngagementRate: metrics.bestEngagementRate,
                consistencyScore: metrics.consistencyScore,
                growthRate7d: creator.followerGrowthRate7d,
                growthRate30d: creator.followerGrowthRate30d,
                authenticityScore: qual.avgAuthenticity,
                communityScore: qual.communityScore,
                commentQuality: qual.avgCommentQuality,
                compositeScore: compositeScore,
                postsAnalyzed: metrics.totalPosts
            )
        }.sorted { $0.compositeScore > $1.compositeScore }
    }

    // MARK: - Content Ideas Report

    func generateContentIdeas() -> [ContentIdea] {
        let pat = patternAnalyzer
        var ideas: [ContentIdea] = []

        for formula in pat.identifyWinningFormulas().prefix(10) {
            ideas.append(ContentIdea(
                formulaName: formula.name,
                description: formula.description,
                hookType: formula.hookTypes.first?.displayName ?? "N/A",
                format: formula.formats.first?.displayName ?? "N/A",
                themes: formula.themes,
                successRate: formula.successRate,
                avgEngagement: formula.avgEngagementRate,
                postsUsingFormula: formula.totalPostsAnalyzed,
                template: pat.generateContentTemplate(for: formula),
                isWhitespaceOpportunity: false,
                opportunityScore: 0
            ))
        }

        for opp in whitespaceAnalyzer.identifyWhitespaceOpportunities().prefix(5) {
            ideas.append(ContentIdea(
                formulaName: "Whitespace: \(opp.topic.capitalized)",
                description: "Underserved topic with high engagement potential",
                hookType: opp.suggestedHooks.first?.displayName ?? "How-To",
                format: opp.suggestedFormats.first?.displayName ?? "Educational",
                themes: [opp.topic],
                successRate: 0,
                avgEngagement: opp.engagementRate,
                postsUsingFormula: 0,
                template: opp.exampleAngles.joined(separator: "\n"),
                isWhitespaceOpportunity: true,
                opportunityScore: opp.opportunityScore
            ))
        }

        return ideas
    }

    // MARK: - Collaboration Targets Report

    func generateCollaborationTargets() -> [CollaborationReportItem] {
        if let collab = collabAnalyzer {
            return collab.findCollaborationTargets().prefix(20).map { t in
                CollaborationReportItem(
                    creatorId: t.id, name: t.creatorName,
                    platform: t.platform, followers: t.followerCount,
                    engagementRate: t.engagementRate, growthRate: t.growthRate,
                    nicheAlignmentScore: t.nicheAlignmentScore,
                    engagementQualityScore: t.engagementQualityScore,
                    overallFitScore: t.overallFitScore,
                    recommendation: CollaborationAnalyzer.recommendation(for: t)
                )
            }
        }

        // Fallback: rank by engagement
        return engagementAnalyzer.rankCreatorsByEngagement().prefix(20).map { c, m in
            CollaborationReportItem(
                creatorId: c.id,
                name: c.displayName.isEmpty ? c.username : c.displayName,
                platform: c.platform, followers: c.followerCount,
                engagementRate: m.avgEngagementRate, growthRate: c.followerGrowthRate30d,
                nicheAlignmentScore: 0, engagementQualityScore: 0,
                overallFitScore: m.avgEngagementRate * 10,
                recommendation: "Based on engagement rate (set target niches for alignment scoring)"
            )
        }
    }

    // MARK: - Trending Report

    struct TrendingReport {
        let topHashtags: [HashtagItem]
        let trendingNow: [TrendItem]
        let bestPostingTimes: TimingAnalysis
    }

    func generateTrendingReport() -> TrendingReport {
        let trend = trendAnalyzer
        return TrendingReport(
            topHashtags: Array(trend.analyzeHashtagPerformance().prefix(20)),
            trendingNow: trend.identifyTrendingTopics().prefix(20).map { t in
                TrendItem(topic: t.topic, growthRate: t.growthRate,
                          postCount: t.postCount, avgEngagement: t.avgEngagementRate)
            },
            bestPostingTimes: trend.analyzeTimingPerformance()
        )
    }
}
