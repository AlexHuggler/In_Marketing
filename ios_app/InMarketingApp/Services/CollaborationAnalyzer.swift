import Foundation

/// Identifies potential collaboration targets based on niche alignment
/// and engagement quality rather than just follower count.
struct CollaborationAnalyzer {
    let creators: [String: Creator]
    let targetNiches: [String]

    // MARK: - Niche Alignment

    func calculateNicheAlignment(for creator: Creator) -> Double {
        let creatorNiches = Set(creator.nicheTags.map { $0.lowercased() })
        let targets = Set(targetNiches.map { $0.lowercased() })

        guard !creatorNiches.isEmpty, !targets.isEmpty else { return 0.0 }

        let matches = creatorNiches.intersection(targets).count
        return min(Double(matches) / Double(targets.count) * 100.0, 100.0)
    }

    // MARK: - Collaboration Scoring

    func scoreCollaborationPotential(for creator: Creator) -> CollaborationTarget {
        let nicheScore = calculateNicheAlignment(for: creator)
        let engScore = min(creator.avgEngagementRate * 20.0, 100.0)
        let growthScore = min(creator.followerGrowthRate30d * 5.0, 100.0)
        let overallScore = (nicheScore * 0.4) + (engScore * 0.35) + (growthScore * 0.25)

        return CollaborationTarget(
            id: creator.id,
            creatorName: creator.displayName.isEmpty ? creator.username : creator.displayName,
            platform: creator.platform,
            nicheAlignmentScore: nicheScore,
            engagementQualityScore: engScore,
            overallFitScore: overallScore,
            followerCount: creator.followerCount,
            engagementRate: creator.avgEngagementRate,
            growthRate: creator.followerGrowthRate30d
        )
    }

    // MARK: - Find Targets

    func findCollaborationTargets(
        minFollowers: Int = 1_000,
        maxFollowers: Int = 1_000_000,
        minAlignment: Double = 30.0
    ) -> [CollaborationTarget] {
        creators.values
            .filter { (minFollowers...maxFollowers).contains($0.followerCount) }
            .map { scoreCollaborationPotential(for: $0) }
            .filter { $0.nicheAlignmentScore >= minAlignment }
            .sorted { $0.overallFitScore > $1.overallFitScore }
    }

    // MARK: - Recommendation Text

    static func recommendation(for target: CollaborationTarget) -> String {
        if target.overallFitScore >= 70 {
            return "Highly recommended - strong niche alignment and engagement"
        } else if target.overallFitScore >= 50 {
            return "Good fit - consider for campaign"
        } else if target.overallFitScore >= 30 {
            return "Potential fit - review content manually"
        } else {
            return "Lower priority - limited alignment"
        }
    }
}
