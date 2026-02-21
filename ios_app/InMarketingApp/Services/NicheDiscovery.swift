import Foundation

/// Discovers and ranks top creators within specific niches.
struct NicheDiscovery {
    let creators: [String: Creator]
    let posts: [Post]

    // MARK: - Niche Groups

    static let nicheGroups: [String: [String]] = [
        "data": [
            "data", "data-analytics", "data analytics", "analytics",
            "data-science", "data science", "datascience",
            "data-engineering", "data engineering", "dataengineering",
            "data-visualization", "data visualization", "dataviz",
            "big-data", "big data", "bigdata",
            "machine-learning", "machine learning", "ml",
            "artificial-intelligence", "artificial intelligence", "ai",
            "statistics", "statistical-analysis",
        ],
        "business-intelligence": [
            "business-intelligence", "business intelligence", "bi",
            "tableau", "power-bi", "power bi", "powerbi",
            "looker", "metabase", "superset",
            "dashboards", "reporting", "kpis", "metrics",
        ],
        "data-professional": [
            "data-professional", "data professional",
            "data-career", "data career", "datacareer",
            "data-training", "data training",
            "sql", "python", "r-programming",
            "excel", "spreadsheets", "data-bootcamp",
        ],
        "tech": [
            "technology", "tech", "software", "programming",
            "coding", "developer", "engineering", "devops",
            "cloud", "aws", "azure", "gcp",
        ],
        "marketing": [
            "marketing", "digital-marketing", "digital marketing",
            "content-marketing", "content marketing",
            "social-media", "social media", "socialmedia",
            "seo", "sem", "growth", "growth-hacking",
            "branding", "advertising", "ads",
        ],
        "business": [
            "business", "entrepreneurship", "startup", "startups",
            "leadership", "management", "strategy",
            "consulting", "mba", "finance",
        ],
        "productivity": [
            "productivity", "efficiency", "time-management",
            "habits", "self-improvement", "personal-development",
            "goal-setting", "focus", "deep-work",
        ],
    ]

    // MARK: - Niche Matching

    private func normalize(_ niche: String) -> String {
        niche.lowercased().trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "_", with: "-")
    }

    private func getRelatedNiches(_ niche: String) -> Set<String> {
        let normalized = normalize(niche)
        var related: Set<String> = [normalized]

        for (groupName, groupTerms) in Self.nicheGroups {
            let normalizedTerms = groupTerms.map { normalize($0) }
            if normalizedTerms.contains(normalized) || normalizedTerms.contains(where: { normalized.contains($0) || $0.contains(normalized) }) {
                related.formUnion(normalizedTerms)
                related.insert(groupName)
            }
        }

        // Partial matches from creator index
        let allCreatorNiches = Set(creators.values.flatMap { $0.nicheTags.map { normalize($0) } })
        for indexed in allCreatorNiches {
            if normalized.contains(indexed) || indexed.contains(normalized) {
                related.insert(indexed)
            }
        }

        return related
    }

    // MARK: - Find Creators

    func findCreatorsByNiche(
        niches: [String],
        includeRelated: Bool = true,
        minFollowers: Int = 0,
        maxFollowers: Int = Int.max,
        minEngagementRate: Double = 0.0,
        platforms: [SocialPlatform]? = nil
    ) -> [Creator] {
        var matchingIds: Set<String> = []

        for niche in niches {
            let searchNiches = includeRelated ? getRelatedNiches(niche) : [normalize(niche)]

            for creator in creators.values {
                let creatorNiches = Set(creator.nicheTags.map { normalize($0) })
                for searchNiche in searchNiches {
                    if creatorNiches.contains(searchNiche) ||
                       creatorNiches.contains(where: { searchNiche.contains($0) || $0.contains(searchNiche) }) {
                        matchingIds.insert(creator.id)
                    }
                }
            }
        }

        return matchingIds.compactMap { creators[$0] }.filter { creator in
            creator.followerCount >= minFollowers &&
            creator.followerCount <= maxFollowers &&
            creator.avgEngagementRate >= minEngagementRate &&
            (platforms == nil || platforms!.contains(creator.platform))
        }
    }

    // MARK: - Rank Creators

    struct RankedCreator: Identifiable {
        let id: String
        let username: String
        let displayName: String
        let platform: SocialPlatform
        let tier: String
        let followerCount: Int
        let primaryNiche: String
        let allNiches: String
        let matchedNiches: Int
        let avgEngagementRate: Double
        let growthRate30d: Double
        let engagementScore: Double
        let growthScore: Double
        let relevanceScore: Double
        let consistencyScore: Double
        let compositeScore: Double
        let recommendation: String
    }

    func rankCreatorsInNiche(
        niches: [String],
        rankingMethod: String = "composite",
        includeRelated: Bool = true,
        topN: Int = 50,
        minFollowers: Int = 0,
        maxFollowers: Int = Int.max,
        minEngagementRate: Double = 0.0,
        platforms: [SocialPlatform]? = nil
    ) -> [RankedCreator] {
        let matchedCreators = findCreatorsByNiche(
            niches: niches, includeRelated: includeRelated,
            minFollowers: minFollowers, maxFollowers: maxFollowers,
            minEngagementRate: minEngagementRate, platforms: platforms
        )

        guard !matchedCreators.isEmpty else { return [] }

        return matchedCreators.map { creator in
            let engagementScore = min(creator.avgEngagementRate * 15.0, 100.0)
            let growthScore = min(max(creator.followerGrowthRate30d, 0) * 3.0, 100.0)
            let matchedNiches = countNicheMatches(creator: creator, targetNiches: niches, includeRelated: includeRelated)
            let relevanceScore = min(Double(matchedNiches) * 25.0, 100.0)

            let creatorPosts = posts.filter { $0.creatorId == creator.id }
            let consistency: Double
            if creatorPosts.count > 1 {
                let engagements = creatorPosts.map { Double($0.metrics.totalEngagements) }
                let avg = engagements.mean
                let cv = avg > 0 ? engagements.standardDeviation / avg : 0
                consistency = max(0, 100.0 - cv * 50.0)
            } else {
                consistency = 50.0
            }

            let score: Double
            switch rankingMethod {
            case "engagement": score = engagementScore
            case "growth": score = growthScore
            case "followers": score = min(Double(creator.followerCount) / 10000.0, 100.0)
            default:
                score = engagementScore * 0.35 + growthScore * 0.20 + relevanceScore * 0.25 + consistency * 0.20
            }

            return RankedCreator(
                id: creator.id, username: creator.username,
                displayName: creator.displayName.isEmpty ? creator.username : creator.displayName,
                platform: creator.platform, tier: creator.tier,
                followerCount: creator.followerCount,
                primaryNiche: creator.primaryNiche,
                allNiches: creator.nicheTags.joined(separator: ", "),
                matchedNiches: matchedNiches,
                avgEngagementRate: creator.avgEngagementRate,
                growthRate30d: creator.followerGrowthRate30d,
                engagementScore: engagementScore, growthScore: growthScore,
                relevanceScore: relevanceScore, consistencyScore: consistency,
                compositeScore: score,
                recommendation: recommendationText(for: score)
            )
        }
        .sorted { $0.compositeScore > $1.compositeScore }
        .prefix(topN)
        .map { $0 }
    }

    private func countNicheMatches(creator: Creator, targetNiches: [String], includeRelated: Bool) -> Int {
        let creatorNiches = Set(creator.nicheTags.map { normalize($0) })
        var matches = 0
        for niche in targetNiches {
            let searchNiches = includeRelated ? getRelatedNiches(niche) : [normalize(niche)]
            if !creatorNiches.intersection(searchNiches).isEmpty { matches += 1 }
        }
        return matches
    }

    private func recommendationText(for score: Double) -> String {
        if score >= 75 { return "Highly recommended - top performer in niche" }
        if score >= 60 { return "Strong candidate - good engagement and relevance" }
        if score >= 45 { return "Worth considering - solid metrics" }
        if score >= 30 { return "Monitor - potential but needs validation" }
        return "Lower priority - limited niche fit"
    }

    // MARK: - Niche Overview

    struct NicheOverview {
        let totalCreators: Int
        let totalReach: Int
        let avgFollowers: Int
        let medianFollowers: Int
        let avgEngagementRate: Double
        let avgGrowth30d: Double
        let creatorsGrowing: Int
        let creatorsDeclining: Int
        let tierDistribution: [String: Int]
        let platformDistribution: [String: Int]
        let competitionLevel: String
    }

    func getNicheOverview(niches: [String], includeRelated: Bool = true) -> NicheOverview {
        let matched = findCreatorsByNiche(niches: niches, includeRelated: includeRelated)
        guard !matched.isEmpty else {
            return NicheOverview(
                totalCreators: 0, totalReach: 0, avgFollowers: 0, medianFollowers: 0,
                avgEngagementRate: 0, avgGrowth30d: 0, creatorsGrowing: 0, creatorsDeclining: 0,
                tierDistribution: [:], platformDistribution: [:], competitionLevel: "N/A"
            )
        }

        let followers = matched.map(\.followerCount)
        let engagement = matched.compactMap { $0.avgEngagementRate > 0 ? $0.avgEngagementRate : nil }
        let growth = matched.map(\.followerGrowthRate30d)

        var tiers: [String: Int] = [:]
        var platforms: [String: Int] = [:]
        for c in matched {
            tiers[c.tier, default: 0] += 1
            platforms[c.platform.displayName, default: 0] += 1
        }

        let competition: String
        switch matched.count {
        case ..<5: competition = "Low - Few creators, high opportunity"
        case ..<20: competition = "Moderate - Growing space with room"
        case ..<50: competition = "Medium - Established but not saturated"
        case ..<100: competition = "High - Competitive, need differentiation"
        default: competition = "Very High - Saturated market"
        }

        let sortedFollowers = followers.sorted()
        let median = sortedFollowers.count % 2 == 0
            ? (sortedFollowers[sortedFollowers.count / 2 - 1] + sortedFollowers[sortedFollowers.count / 2]) / 2
            : sortedFollowers[sortedFollowers.count / 2]

        return NicheOverview(
            totalCreators: matched.count,
            totalReach: followers.reduce(0, +),
            avgFollowers: followers.reduce(0, +) / matched.count,
            medianFollowers: median,
            avgEngagementRate: engagement.mean,
            avgGrowth30d: growth.mean,
            creatorsGrowing: growth.filter { $0 > 0 }.count,
            creatorsDeclining: growth.filter { $0 < 0 }.count,
            tierDistribution: tiers,
            platformDistribution: platforms,
            competitionLevel: competition
        )
    }

    // MARK: - Rising Stars

    struct RisingStar: Identifiable {
        let id: String
        let username: String
        let displayName: String
        let platform: SocialPlatform
        let followerCount: Int
        let growthRate30d: Double
        let engagementRate: Double
        let niches: String
        let starScore: Double
        let potential: String
    }

    func findRisingStars(
        niches: [String],
        minGrowthRate: Double = 5.0,
        maxFollowers: Int = 100_000,
        topN: Int = 20
    ) -> [RisingStar] {
        findCreatorsByNiche(niches: niches, includeRelated: true, maxFollowers: maxFollowers)
            .filter { $0.followerGrowthRate30d >= minGrowthRate }
            .map { creator in
                let starScore = creator.followerGrowthRate30d * 2.0 + creator.avgEngagementRate * 10.0
                let potential: String
                if creator.followerGrowthRate30d > 20, creator.avgEngagementRate > 5 {
                    potential = "Very High - Viral trajectory with strong engagement"
                } else if creator.followerGrowthRate30d > 10, creator.avgEngagementRate > 3 {
                    potential = "High - Strong growth with solid engagement"
                } else if creator.followerGrowthRate30d > 5 {
                    potential = "Good - Steady growth, worth monitoring"
                } else {
                    potential = "Moderate - Growing but slower pace"
                }

                return RisingStar(
                    id: creator.id, username: creator.username,
                    displayName: creator.displayName.isEmpty ? creator.username : creator.displayName,
                    platform: creator.platform,
                    followerCount: creator.followerCount,
                    growthRate30d: creator.followerGrowthRate30d,
                    engagementRate: creator.avgEngagementRate,
                    niches: creator.nicheTags.joined(separator: ", "),
                    starScore: starScore, potential: potential
                )
            }
            .sorted { $0.starScore > $1.starScore }
            .prefix(topN)
            .map { $0 }
    }
}
