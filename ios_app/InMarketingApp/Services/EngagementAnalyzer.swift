import Foundation

/// Analyzes engagement metrics for posts and creators.
/// Key insight: Track engagement RATE + VELOCITY rather than raw likes.
struct EngagementAnalyzer {
    let posts: [Post]
    let creators: [String: Creator]

    // MARK: - Post-Level Analysis

    func calculateEngagementRate(for post: Post, audienceSize: Int? = nil) -> Double {
        let totalEngagements = Double(post.metrics.totalEngagements)
        let audience: Double

        if let size = audienceSize {
            audience = Double(size)
        } else if post.metrics.views > 0 {
            audience = Double(post.metrics.views)
        } else if let creator = creators[post.creatorId] {
            audience = Double(creator.followerCount)
        } else {
            audience = Double(max(post.metrics.likes * 10, 1))
        }

        guard audience > 0 else { return 0.0 }
        return (totalEngagements / audience) * 100.0
    }

    func calculateEngagementVelocity(for post: Post) -> Double {
        if post.engagements24h > 0 {
            return Double(post.engagements24h) / 24.0
        } else if post.engagements6h > 0 {
            return Double(post.engagements6h) / 6.0
        } else if post.engagements1h > 0 {
            return Double(post.engagements1h)
        } else {
            let hoursSincePost = max(1.0, Date().timeIntervalSince(post.timestamp) / 3600.0)
            return Double(post.metrics.totalEngagements) / hoursSincePost
        }
    }

    func calculateViralCoefficient(for post: Post) -> Double {
        let baseEngagement = post.metrics.likes + post.metrics.comments
        guard baseEngagement > 0 else { return 0.0 }
        return Double(post.metrics.shares) / Double(baseEngagement)
    }

    func calculateSaveRate(for post: Post) -> Double {
        if post.metrics.views > 0 {
            return (Double(post.metrics.saves) / Double(post.metrics.views)) * 100.0
        } else if post.metrics.likes > 0 {
            return (Double(post.metrics.saves) / Double(post.metrics.likes * 10)) * 100.0
        }
        return 0.0
    }

    func analyzePost(_ post: Post) -> [String: Double] {
        [
            "engagementRate": calculateEngagementRate(for: post),
            "engagementVelocity": calculateEngagementVelocity(for: post),
            "viralCoefficient": calculateViralCoefficient(for: post),
            "saveRate": calculateSaveRate(for: post),
            "totalEngagements": Double(post.metrics.totalEngagements),
        ]
    }

    // MARK: - All Posts Analysis

    struct PostAnalysis: Identifiable {
        let id: String
        let creatorId: String
        let platform: String
        let timestamp: Date
        let textPreview: String
        let engagementRate: Double
        let engagementVelocity: Double
        let viralCoefficient: Double
        let saveRate: Double
        let totalEngagements: Int
    }

    func analyzeAllPosts() -> [PostAnalysis] {
        posts.map { post in
            PostAnalysis(
                id: post.id,
                creatorId: post.creatorId,
                platform: post.platform.rawValue,
                timestamp: post.timestamp,
                textPreview: String(post.text.prefix(100)) + (post.text.count > 100 ? "..." : ""),
                engagementRate: calculateEngagementRate(for: post),
                engagementVelocity: calculateEngagementVelocity(for: post),
                viralCoefficient: calculateViralCoefficient(for: post),
                saveRate: calculateSaveRate(for: post),
                totalEngagements: post.metrics.totalEngagements
            )
        }.sorted { $0.engagementRate > $1.engagementRate }
    }

    // MARK: - Creator-Level Analysis

    struct CreatorMetrics {
        let avgEngagementRate: Double
        let avgVelocity: Double
        let consistencyScore: Double
        let totalPosts: Int
        let bestEngagementRate: Double
        let worstEngagementRate: Double
    }

    func calculateCreatorMetrics(for creator: Creator) -> CreatorMetrics {
        let creatorPosts = posts.filter { $0.creatorId == creator.id }
        guard !creatorPosts.isEmpty else {
            return CreatorMetrics(
                avgEngagementRate: 0, avgVelocity: 0,
                consistencyScore: 0, totalPosts: 0,
                bestEngagementRate: 0, worstEngagementRate: 0
            )
        }

        let engagementRates = creatorPosts.map { calculateEngagementRate(for: $0) }
        let velocities = creatorPosts.map { calculateEngagementVelocity(for: $0) }

        let avgRate = engagementRates.mean
        let avgVelocity = velocities.mean

        let consistency: Double
        if engagementRates.count > 1, avgRate > 0 {
            let stdDev = engagementRates.standardDeviation
            consistency = max(0, 100.0 - (stdDev / avgRate * 100.0))
        } else {
            consistency = 50.0
        }

        return CreatorMetrics(
            avgEngagementRate: avgRate,
            avgVelocity: avgVelocity,
            consistencyScore: consistency,
            totalPosts: creatorPosts.count,
            bestEngagementRate: engagementRates.max() ?? 0,
            worstEngagementRate: engagementRates.min() ?? 0
        )
    }

    func rankCreatorsByEngagement() -> [(Creator, CreatorMetrics)] {
        creators.values
            .map { ($0, calculateCreatorMetrics(for: $0)) }
            .sorted { $0.1.avgEngagementRate > $1.1.avgEngagementRate }
    }

    func identifyFastestGrowing(minPosts: Int = 3) -> [(Creator, Double)] {
        var growthScores: [(Creator, Double)] = []

        for creator in creators.values {
            let creatorPosts = posts
                .filter { $0.creatorId == creator.id }
                .sorted { $0.timestamp < $1.timestamp }

            guard creatorPosts.count >= minPosts else { continue }

            let midpoint = creatorPosts.count / 2
            let olderPosts = Array(creatorPosts.prefix(midpoint))
            let newerPosts = Array(creatorPosts.suffix(from: midpoint))

            let oldAvg = olderPosts.map { calculateEngagementRate(for: $0) }.mean
            let newAvg = newerPosts.map { calculateEngagementRate(for: $0) }.mean

            let growthRate: Double
            if oldAvg > 0 {
                growthRate = ((newAvg - oldAvg) / oldAvg) * 100.0
            } else {
                growthRate = newAvg > 0 ? newAvg * 100.0 : 0.0
            }

            growthScores.append((creator, growthRate))
        }

        return growthScores.sorted { $0.1 > $1.1 }
    }

    func topPerformingPosts(n: Int = 10) -> [Post] {
        let analyzed = analyzeAllPosts()
        let topIds = Set(analyzed.prefix(n).map(\.id))
        return posts.filter { topIds.contains($0.id) }
    }
}

// MARK: - Array Math Helpers

extension Array where Element == Double {
    var mean: Double {
        guard !isEmpty else { return 0.0 }
        return reduce(0, +) / Double(count)
    }

    var standardDeviation: Double {
        guard count > 1 else { return 0.0 }
        let avg = mean
        let variance = map { ($0 - avg) * ($0 - avg) }.reduce(0, +) / Double(count - 1)
        return variance.squareRoot()
    }
}
