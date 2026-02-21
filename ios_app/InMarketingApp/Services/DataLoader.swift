import Foundation
import UniformTypeIdentifiers

/// Unified data loader for influencer research.
/// Supports CSV and JSON data sources.
class DataLoader {
    var posts: [Post] = []
    var creators: [String: Creator] = [:]
    var loadErrors: [String] = []

    // MARK: - Platform / Media Mappings

    private static let platformMap: [String: SocialPlatform] = [
        "instagram": .instagram, "tiktok": .tiktok, "twitter": .twitter,
        "x": .twitter, "linkedin": .linkedin, "youtube": .youtube,
        "facebook": .facebook, "threads": .threads,
    ]

    private static let mediaTypeMap: [String: MediaType] = [
        "text": .text, "image": .image, "photo": .image, "video": .video,
        "carousel": .carousel, "story": .story, "reel": .reel, "reels": .reel,
        "live": .live, "article": .article, "thread": .thread,
    ]

    // MARK: - CSV Parsing

    func loadPostsFromCSV(content: String) -> [Post] {
        let rows = parseCSV(content)
        guard !rows.isEmpty else { return [] }

        let headers = rows[0].map { $0.lowercased().trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " ", with: "_") }
        var newPosts: [Post] = []

        for row in rows.dropFirst() {
            guard row.count >= headers.count else { continue }
            let dict = Dictionary(uniqueKeysWithValues: zip(headers, row))
            if let post = parsePostRow(dict) {
                newPosts.append(post)
                posts.append(post)
            }
        }
        return newPosts
    }

    func loadCreatorsFromCSV(content: String) -> [Creator] {
        let rows = parseCSV(content)
        guard !rows.isEmpty else { return [] }

        let headers = rows[0].map { $0.lowercased().trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " ", with: "_") }
        var newCreators: [Creator] = []

        for row in rows.dropFirst() {
            guard row.count >= headers.count else { continue }
            let dict = Dictionary(uniqueKeysWithValues: zip(headers, row))
            if let creator = parseCreatorRow(dict) {
                newCreators.append(creator)
                creators[creator.id] = creator
            }
        }
        return newCreators
    }

    // MARK: - JSON Loading

    func loadFromJSON(content: Data) -> (posts: [Post], creators: [Creator]) {
        guard let json = try? JSONSerialization.jsonObject(with: content) as? [String: Any] else {
            loadErrors.append("Invalid JSON format")
            return ([], [])
        }

        var newPosts: [Post] = []
        var newCreators: [Creator] = []

        if let postsArray = json["posts"] as? [[String: Any]] {
            for dict in postsArray {
                let strDict = dict.mapValues { "\($0)" }
                if let post = parsePostRow(strDict) {
                    newPosts.append(post)
                    posts.append(post)
                }
            }
        }

        if let creatorsArray = json["creators"] as? [[String: Any]] {
            for dict in creatorsArray {
                let strDict = dict.mapValues { "\($0)" }
                if let creator = parseCreatorRow(strDict) {
                    newCreators.append(creator)
                    creators[creator.id] = creator
                }
            }
        }

        return (newPosts, newCreators)
    }

    // MARK: - Link Posts to Creators

    func linkPostsToCreators() {
        for post in posts {
            if var creator = creators[post.creatorId] {
                creator.posts.append(post)
                creators[post.creatorId] = creator
            }
        }
    }

    // MARK: - Filtering

    func postsByPlatform(_ platform: SocialPlatform) -> [Post] {
        posts.filter { $0.platform == platform }
    }

    func creatorsByNiche(_ niche: String) -> [Creator] {
        let lower = niche.lowercased()
        return creators.values.filter { $0.nicheTags.map(\.lowercased).contains(lower) }
    }

    // MARK: - JSON Export

    func exportToJSON() -> Data? {
        let data: [String: Any] = [
            "posts": posts.map { postToDict($0) },
            "creators": creators.values.map { creatorToDict($0) },
            "metadata": [
                "exported_at": ISO8601DateFormatter().string(from: Date()),
                "total_posts": posts.count,
                "total_creators": creators.count,
            ],
        ]
        return try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
    }

    // MARK: - Private Helpers

    private func getValue(_ dict: [String: String], keys: [String]) -> String? {
        for key in keys {
            if let val = dict[key], !val.isEmpty, val != "nan" { return val }
        }
        return nil
    }

    private func parsePostRow(_ dict: [String: String]) -> Post? {
        guard let postId = getValue(dict, keys: ["post_id", "id", "content_id"]) else { return nil }
        let creatorId = getValue(dict, keys: ["creator_id", "author_id", "user_id", "account_id"]) ?? ""

        let platformStr = getValue(dict, keys: ["platform", "network", "source"])?.lowercased() ?? "other"
        let platform = Self.platformMap[platformStr] ?? .other

        let text = getValue(dict, keys: ["text", "content", "caption", "body", "message"]) ?? ""

        let mediaStr = getValue(dict, keys: ["media_type", "type", "content_type", "format"])?.lowercased() ?? "text"
        let mediaType = Self.mediaTypeMap[mediaStr] ?? .text

        let timestamp = parseTimestamp(getValue(dict, keys: ["timestamp", "date", "created_at", "posted_at"]))

        let hashtags = parseList(getValue(dict, keys: ["hashtags", "tags", "hash_tags"]))
        let topics = parseList(getValue(dict, keys: ["topics", "categories", "topic"]))

        let metrics = EngagementMetrics(
            likes: Int(getValue(dict, keys: ["likes", "like_count", "hearts"]) ?? "0") ?? 0,
            comments: Int(getValue(dict, keys: ["comments", "comment_count", "replies"]) ?? "0") ?? 0,
            shares: Int(getValue(dict, keys: ["shares", "share_count", "reposts", "retweets"]) ?? "0") ?? 0,
            saves: Int(getValue(dict, keys: ["saves", "save_count", "bookmarks"]) ?? "0") ?? 0,
            views: Int(getValue(dict, keys: ["views", "view_count", "impressions", "plays"]) ?? "0") ?? 0,
            reach: Int(getValue(dict, keys: ["reach", "unique_views"]) ?? "0") ?? 0
        )

        return Post(
            id: postId, creatorId: creatorId, platform: platform,
            text: text, mediaType: mediaType, timestamp: timestamp,
            hashtags: hashtags, topics: topics, metrics: metrics,
            engagements1h: Int(getValue(dict, keys: ["engagements_1h", "eng_1h"]) ?? "0") ?? 0,
            engagements6h: Int(getValue(dict, keys: ["engagements_6h", "eng_6h"]) ?? "0") ?? 0,
            engagements24h: Int(getValue(dict, keys: ["engagements_24h", "eng_24h"]) ?? "0") ?? 0
        )
    }

    private func parseCreatorRow(_ dict: [String: String]) -> Creator? {
        guard let creatorId = getValue(dict, keys: ["creator_id", "id", "user_id", "account_id"]) else { return nil }
        let username = getValue(dict, keys: ["username", "handle", "screen_name"]) ?? ""

        let platformStr = getValue(dict, keys: ["platform", "network", "source"])?.lowercased() ?? "other"
        let platform = Self.platformMap[platformStr] ?? .other

        let displayName = getValue(dict, keys: ["display_name", "name", "full_name"]) ?? username
        let bio = getValue(dict, keys: ["bio", "description", "about"]) ?? ""

        let followerCount = Int(getValue(dict, keys: ["follower_count", "followers", "subscriber_count"]) ?? "0") ?? 0
        let followingCount = Int(getValue(dict, keys: ["following_count", "following"]) ?? "0") ?? 0

        let nicheTags = parseList(getValue(dict, keys: ["niche_tags", "niches", "niche", "categories"]))
        let primaryNiche = nicheTags.first ?? ""

        return Creator(
            id: creatorId, username: username, platform: platform,
            displayName: displayName, bio: bio,
            followerCount: followerCount, followingCount: followingCount,
            nicheTags: nicheTags, primaryNiche: primaryNiche,
            secondaryNiches: Array(nicheTags.dropFirst()),
            totalPosts: Int(getValue(dict, keys: ["total_posts", "post_count", "posts"]) ?? "0") ?? 0,
            avgEngagementRate: Double(getValue(dict, keys: ["avg_engagement_rate", "engagement_rate"]) ?? "0") ?? 0,
            avgLikes: Double(getValue(dict, keys: ["avg_likes", "average_likes"]) ?? "0") ?? 0,
            avgComments: Double(getValue(dict, keys: ["avg_comments", "average_comments"]) ?? "0") ?? 0,
            followerGrowthRate7d: Double(getValue(dict, keys: ["growth_rate_7d", "weekly_growth"]) ?? "0") ?? 0,
            followerGrowthRate30d: Double(getValue(dict, keys: ["growth_rate_30d", "monthly_growth"]) ?? "0") ?? 0,
            lastUpdated: Date()
        )
    }

    private func parseTimestamp(_ value: String?) -> Date {
        guard let value = value else { return Date() }
        let formats = [
            "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss'Z'", "yyyy-MM-dd",
            "MM/dd/yyyy HH:mm:ss", "MM/dd/yyyy", "dd/MM/yyyy",
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for fmt in formats {
            formatter.dateFormat = fmt
            if let date = formatter.date(from: value) { return date }
        }
        return Date()
    }

    private func parseList(_ value: String?) -> [String] {
        guard let value = value, !value.isEmpty else { return [] }
        if value.contains(",") {
            return value.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        if value.contains(";") {
            return value.split(separator: ";").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        return [value.trimmingCharacters(in: .whitespaces)].filter { !$0.isEmpty }
    }

    private func parseCSV(_ content: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var insideQuotes = false

        for char in content {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                currentRow.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            } else if char == "\n" && !insideQuotes {
                currentRow.append(currentField.trimmingCharacters(in: .whitespaces))
                if !currentRow.allSatisfy({ $0.isEmpty }) {
                    rows.append(currentRow)
                }
                currentRow = []
                currentField = ""
            } else if char != "\r" {
                currentField.append(char)
            }
        }

        // Handle last field/row
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField.trimmingCharacters(in: .whitespaces))
            if !currentRow.allSatisfy({ $0.isEmpty }) {
                rows.append(currentRow)
            }
        }

        return rows
    }

    private func postToDict(_ post: Post) -> [String: Any] {
        [
            "post_id": post.id, "creator_id": post.creatorId,
            "platform": post.platform.rawValue, "text": post.text,
            "media_type": post.mediaType.rawValue,
            "timestamp": ISO8601DateFormatter().string(from: post.timestamp),
            "hashtags": post.hashtags, "topics": post.topics,
            "metrics": [
                "likes": post.metrics.likes, "comments": post.metrics.comments,
                "shares": post.metrics.shares, "saves": post.metrics.saves,
                "views": post.metrics.views,
            ],
        ]
    }

    private func creatorToDict(_ creator: Creator) -> [String: Any] {
        [
            "creator_id": creator.id, "username": creator.username,
            "platform": creator.platform.rawValue,
            "display_name": creator.displayName,
            "follower_count": creator.followerCount,
            "niche_tags": creator.nicheTags,
            "primary_niche": creator.primaryNiche,
            "avg_engagement_rate": creator.avgEngagementRate,
            "follower_growth_rate_7d": creator.followerGrowthRate7d,
            "follower_growth_rate_30d": creator.followerGrowthRate30d,
        ]
    }
}
