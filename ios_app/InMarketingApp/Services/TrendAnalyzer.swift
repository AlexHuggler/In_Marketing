import Foundation

/// Analyzes trends in topics, hashtags, and content patterns.
struct TrendAnalyzer {
    let posts: [Post]
    var engagementAnalyzer: EngagementAnalyzer?

    // MARK: - Hashtag Performance

    func analyzeHashtagPerformance() -> [HashtagItem] {
        var hashtagStats: [String: (posts: [Post], totalEngagement: Int, totalLikes: Int, totalComments: Int)] = [:]

        for post in posts {
            for hashtag in post.hashtags {
                let tag = hashtag.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "#"))
                var stats = hashtagStats[tag] ?? (posts: [], totalEngagement: 0, totalLikes: 0, totalComments: 0)
                stats.posts.append(post)
                stats.totalEngagement += post.metrics.totalEngagements
                stats.totalLikes += post.metrics.likes
                stats.totalComments += post.metrics.comments
                hashtagStats[tag] = stats
            }
        }

        return hashtagStats.compactMap { hashtag, stats in
            let postCount = stats.posts.count
            guard postCount > 0 else { return nil }

            let avgEngagement = Double(stats.totalEngagement) / Double(postCount)
            let avgRate: Double
            if let analyzer = engagementAnalyzer {
                avgRate = stats.posts.map { analyzer.calculateEngagementRate(for: $0) }.mean
            } else {
                avgRate = 0
            }

            return HashtagItem(
                hashtag: "#\(hashtag)",
                postCount: postCount,
                totalEngagement: stats.totalEngagement,
                avgEngagement: avgEngagement,
                avgEngagementRate: avgRate,
                avgLikes: Double(stats.totalLikes) / Double(postCount),
                avgComments: Double(stats.totalComments) / Double(postCount)
            )
        }.sorted { $0.avgEngagementRate > $1.avgEngagementRate }
    }

    // MARK: - Topic Performance

    struct TopicPerformance: Identifiable {
        let id = UUID()
        let topic: String
        let postCount: Int
        let totalEngagement: Int
        let avgEngagement: Double
        let avgEngagementRate: Double
    }

    func analyzeTopicPerformance() -> [TopicPerformance] {
        var topicStats: [String: (posts: [Post], totalEngagement: Int)] = [:]

        for post in posts {
            for topic in post.topics {
                let key = topic.lowercased()
                var stats = topicStats[key] ?? (posts: [], totalEngagement: 0)
                stats.posts.append(post)
                stats.totalEngagement += post.metrics.totalEngagements
                topicStats[key] = stats
            }
        }

        return topicStats.compactMap { topic, stats in
            let postCount = stats.posts.count
            guard postCount > 0 else { return nil }

            let avgRate: Double
            if let analyzer = engagementAnalyzer {
                avgRate = stats.posts.map { analyzer.calculateEngagementRate(for: $0) }.mean
            } else {
                avgRate = 0
            }

            return TopicPerformance(
                topic: topic,
                postCount: postCount,
                totalEngagement: stats.totalEngagement,
                avgEngagement: Double(stats.totalEngagement) / Double(postCount),
                avgEngagementRate: avgRate
            )
        }.sorted { $0.avgEngagementRate > $1.avgEngagementRate }
    }

    // MARK: - Trending Topics

    func identifyTrendingTopics(daysWindow: Int = 7) -> [TrendingTopic] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -daysWindow, to: Date()) ?? Date()
        let recentPosts = posts.filter { $0.timestamp >= cutoff }
        let olderPosts = posts.filter { $0.timestamp < cutoff }

        var recentTopics: [String: Int] = [:]
        var olderTopics: [String: Int] = [:]

        for post in recentPosts {
            for topic in post.topics { recentTopics[topic.lowercased(), default: 0] += 1 }
            for tag in post.hashtags { recentTopics[tag.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "#")), default: 0] += 1 }
        }
        for post in olderPosts {
            for topic in post.topics { olderTopics[topic.lowercased(), default: 0] += 1 }
            for tag in post.hashtags { olderTopics[tag.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "#")), default: 0] += 1 }
        }

        return recentTopics.map { topic, recentCount in
            let oldCount = olderTopics[topic] ?? 0
            let growthRate: Double = oldCount > 0
                ? (Double(recentCount - oldCount) / Double(oldCount)) * 100.0
                : 100.0

            let topicPosts = recentPosts.filter {
                $0.topics.map(\.lowercased).contains(topic) ||
                $0.hashtags.map { $0.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "#")) }.contains(topic)
            }

            let totalEngagement = topicPosts.reduce(0) { $0 + $1.metrics.totalEngagements }
            let avgEngagement = topicPosts.isEmpty ? 0.0 : Double(totalEngagement) / Double(topicPosts.count)

            return TrendingTopic(
                topic: topic,
                platform: .other,
                postCount: recentCount,
                totalEngagement: totalEngagement,
                avgEngagementRate: avgEngagement,
                growthRate: growthRate,
                firstSeen: topicPosts.map(\.timestamp).min()
            )
        }.sorted { $0.growthRate > $1.growthRate }
    }

    // MARK: - Timing Performance

    func analyzeTimingPerformance() -> TimingAnalysis {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"

        var dayStats: [String: (posts: [Post], totalEngagement: Int)] = [:]
        var hourStats: [Int: (posts: [Post], totalEngagement: Int)] = [:]

        for post in posts {
            let day = formatter.string(from: post.timestamp)
            let hour = Calendar.current.component(.hour, from: post.timestamp)

            var dStat = dayStats[day] ?? (posts: [], totalEngagement: 0)
            dStat.posts.append(post)
            dStat.totalEngagement += post.metrics.totalEngagements
            dayStats[day] = dStat

            var hStat = hourStats[hour] ?? (posts: [], totalEngagement: 0)
            hStat.posts.append(post)
            hStat.totalEngagement += post.metrics.totalEngagements
            hourStats[hour] = hStat
        }

        let bestDays = dayStats.map { day, stats in
            TimingItem(
                label: day,
                avgEngagement: stats.posts.isEmpty ? 0 : Double(stats.totalEngagement) / Double(stats.posts.count),
                postCount: stats.posts.count
            )
        }.sorted { $0.avgEngagement > $1.avgEngagement }

        let bestHours = hourStats.map { hour, stats in
            TimingItem(
                label: String(format: "%02d:00", hour),
                avgEngagement: stats.posts.isEmpty ? 0 : Double(stats.totalEngagement) / Double(stats.posts.count),
                postCount: stats.posts.count
            )
        }.sorted { $0.avgEngagement > $1.avgEngagement }

        return TimingAnalysis(bestDays: bestDays, bestHours: bestHours)
    }
}
