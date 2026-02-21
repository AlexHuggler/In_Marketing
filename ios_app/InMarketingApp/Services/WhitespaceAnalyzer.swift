import Foundation

/// Identifies whitespace opportunities: high-demand topics with low creator saturation.
struct WhitespaceAnalyzer {
    let posts: [Post]
    let creators: [String: Creator]

    // MARK: - Topic Saturation

    struct TopicSaturation: Identifiable {
        let id = UUID()
        let topic: String
        let creatorCount: Int
        let postCount: Int
        let avgEngagement: Double
        let saturationScore: Double
        let opportunityScore: Double
    }

    func analyzeTopicSaturation() -> [TopicSaturation] {
        var topicData: [String: (creators: Set<String>, posts: [Post], totalEngagement: Int)] = [:]

        for post in posts {
            for topic in post.topics {
                let key = topic.lowercased()
                var data = topicData[key] ?? (creators: [], posts: [], totalEngagement: 0)
                data.creators.insert(post.creatorId)
                data.posts.append(post)
                data.totalEngagement += post.metrics.totalEngagements
                topicData[key] = data
            }
        }

        let maxCreators = max(Double(creators.count), 1.0)

        return topicData.compactMap { topic, data in
            let postCount = data.posts.count
            let creatorCount = data.creators.count
            guard postCount > 0 else { return nil }

            let avgEngagement = Double(data.totalEngagement) / Double(postCount)
            let saturationScore = (Double(creatorCount) / maxCreators) * 100.0
            let opportunityScore = avgEngagement * (100.0 - saturationScore) / 100.0

            return TopicSaturation(
                topic: topic,
                creatorCount: creatorCount,
                postCount: postCount,
                avgEngagement: avgEngagement,
                saturationScore: saturationScore,
                opportunityScore: opportunityScore
            )
        }.sorted { $0.opportunityScore > $1.opportunityScore }
    }

    // MARK: - Whitespace Opportunities

    func identifyWhitespaceOpportunities(minEngagement: Double = 100) -> [WhitespaceOpportunity] {
        analyzeTopicSaturation()
            .filter { $0.avgEngagement >= minEngagement }
            .map { data in
                let priority: String
                if data.opportunityScore > 500 { priority = "High" }
                else if data.opportunityScore > 200 { priority = "Medium" }
                else { priority = "Low" }

                return WhitespaceOpportunity(
                    id: "ws_\(data.topic.replacingOccurrences(of: " ", with: "_"))",
                    topic: data.topic,
                    niche: data.topic,
                    engagementRate: data.avgEngagement,
                    creatorCount: data.creatorCount,
                    competitionScore: data.saturationScore,
                    opportunityScore: data.opportunityScore,
                    recommendedPriority: priority,
                    suggestedHooks: [.howTo, .listicle, .personalExperience],
                    suggestedFormats: [.educational, .shortForm],
                    exampleAngles: [
                        "Beginner's guide to \(data.topic)",
                        "Common mistakes in \(data.topic)",
                        "My journey learning \(data.topic)",
                    ]
                )
            }
    }

    // MARK: - Underserved Niches

    struct UnderservedNiche: Identifiable {
        let id = UUID()
        let niche: String
        let creatorCount: Int
        let totalAudience: Int
        let avgEngagementRate: Double
        let audiencePerCreator: Double
    }

    func findUnderservedNiches() -> [UnderservedNiche] {
        var nicheData: [String: (creators: [Creator], totalFollowers: Int, engagementRates: [Double])] = [:]

        for creator in creators.values {
            for niche in creator.nicheTags {
                let key = niche.lowercased()
                var data = nicheData[key] ?? (creators: [], totalFollowers: 0, engagementRates: [])
                data.creators.append(creator)
                data.totalFollowers += creator.followerCount
                if creator.avgEngagementRate > 0 {
                    data.engagementRates.append(creator.avgEngagementRate)
                }
                nicheData[key] = data
            }
        }

        return nicheData.compactMap { niche, data in
            let creatorCount = data.creators.count
            guard creatorCount > 0 else { return nil }

            return UnderservedNiche(
                niche: niche,
                creatorCount: creatorCount,
                totalAudience: data.totalFollowers,
                avgEngagementRate: data.engagementRates.mean,
                audiencePerCreator: Double(data.totalFollowers) / Double(creatorCount)
            )
        }.sorted { $0.avgEngagementRate > $1.avgEngagementRate }
    }
}
