import Foundation

/// Analyzes comment quality and engagement authenticity.
struct SentimentAnalyzer {

    // MARK: - Word Lists

    private static let positiveWords: Set<String> = [
        "love", "amazing", "awesome", "great", "excellent", "fantastic",
        "incredible", "brilliant", "perfect", "helpful", "informative",
        "inspiring", "valuable", "thank", "thanks", "appreciate", "best",
        "beautiful", "wonderful", "insightful", "genius", "fire", "lit",
        "goated", "based", "real", "truth", "exactly", "agree", "yes",
    ]

    private static let negativeWords: Set<String> = [
        "hate", "terrible", "awful", "bad", "worst", "horrible", "stupid",
        "boring", "useless", "wrong", "fake", "scam", "spam", "annoying",
        "misleading", "garbage", "trash", "cringe", "cap", "mid",
        "disagree", "false", "lie", "lying", "no", "never",
    ]

    private static let spamPatterns: [String] = [
        "check out my", "follow me", "dm me", "click link",
        "free followers", "make money", "\\$\\d+", "promo code",
        "bio link", "link in bio", "check bio",
    ]

    private static let expertIndicators: [String] = [
        "verified", "author", "ceo", "founder", "phd", "dr.", "professor",
        "expert", "specialist", "consultant", "coach", "trainer",
    ]

    // MARK: - Comment Sentiment

    func analyzeCommentSentiment(_ text: String) -> Double {
        guard !text.isEmpty else { return 0.0 }

        let words = Set(text.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { !$0.isEmpty })

        let positiveCount = words.intersection(Self.positiveWords).count
        let negativeCount = words.intersection(Self.negativeWords).count
        let total = positiveCount + negativeCount
        guard total > 0 else { return 0.0 }

        return max(-1.0, min(1.0, Double(positiveCount - negativeCount) / Double(total)))
    }

    // MARK: - Spam Detection

    func isSpamComment(_ text: String) -> Bool {
        guard !text.isEmpty else { return true }
        if text.count < 3 { return true }

        let lower = text.lowercased()
        for pattern in Self.spamPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(lower.startIndex..., in: lower)
                if regex.firstMatch(in: lower, range: range) != nil { return true }
            }
        }
        return false
    }

    // MARK: - Meaningful Comment

    func isMeaningfulComment(_ text: String, minWords: Int = 5) -> Bool {
        guard !text.isEmpty, !isSpamComment(text) else { return false }
        let wordCount = text.split(separator: " ").count
        let hasQuestion = text.contains("?")
        let hasSpecifics = text.contains(where: \.isNumber) || text.contains("@")
        return wordCount >= minWords || hasQuestion || hasSpecifics
    }

    // MARK: - Expert Detection

    func isExpertCommenter(username: String, bio: String = "") -> Bool {
        let combined = "\(username) \(bio)".lowercased()
        return Self.expertIndicators.contains { combined.contains($0) }
    }

    // MARK: - Post Comment Analysis

    struct PostCommentAnalysis {
        let totalComments: Int
        let avgSentiment: Double
        let spamPercentage: Double
        let meaningfulPercentage: Double
        let expertComments: Int
        let commentQualityScore: Double
    }

    func analyzePostComments(_ post: Post) -> PostCommentAnalysis {
        guard !post.commentsList.isEmpty else {
            return PostCommentAnalysis(
                totalComments: 0, avgSentiment: 0, spamPercentage: 0,
                meaningfulPercentage: 0, expertComments: 0, commentQualityScore: 0
            )
        }

        let total = post.commentsList.count
        var spamCount = 0
        var meaningfulCount = 0
        var expertCount = 0
        var sentiments: [Double] = []

        for comment in post.commentsList {
            let isSpam = isSpamComment(comment.text)
            if isSpam { spamCount += 1 }
            if isMeaningfulComment(comment.text) { meaningfulCount += 1 }
            if comment.isExpert { expertCount += 1 }
            if !isSpam { sentiments.append(analyzeCommentSentiment(comment.text)) }
        }

        let avgSentiment = sentiments.isEmpty ? 0.0 : sentiments.mean
        let spamPct = Double(spamCount) / Double(total) * 100.0
        let meaningfulPct = Double(meaningfulCount) / Double(total) * 100.0

        let qualityScore =
            meaningfulPct * 0.4 +
            (100.0 - spamPct) * 0.3 +
            (avgSentiment + 1.0) * 50.0 * 0.2 +
            min(Double(expertCount) / Double(max(total, 1)) * 100.0, 100.0) * 0.1

        return PostCommentAnalysis(
            totalComments: total,
            avgSentiment: avgSentiment,
            spamPercentage: spamPct,
            meaningfulPercentage: meaningfulPct,
            expertComments: expertCount,
            commentQualityScore: qualityScore
        )
    }
}

// MARK: - Engagement Quality Analyzer

struct EngagementQualityAnalyzer {
    let posts: [Post]
    private let sentimentAnalyzer = SentimentAnalyzer()

    func identifyRepeatedCommenters(creatorId: String) -> [String: Int] {
        var counts: [String: Int] = [:]
        for post in posts where post.creatorId == creatorId {
            for comment in post.commentsList {
                counts[comment.authorUsername, default: 0] += 1
            }
        }
        return counts.filter { $0.value > 1 }
    }

    func calculateCommunityScore(creatorId: String) -> Double {
        let repeated = identifyRepeatedCommenters(creatorId: creatorId)
        let creatorPosts = posts.filter { $0.creatorId == creatorId }
        guard !creatorPosts.isEmpty else { return 0.0 }

        var allCommenters: Set<String> = []
        for post in creatorPosts {
            for comment in post.commentsList {
                allCommenters.insert(comment.authorUsername)
            }
        }
        guard !allCommenters.isEmpty else { return 0.0 }

        let repeatPct = Double(repeated.count) / Double(allCommenters.count) * 100.0
        let avgRepeats = repeated.isEmpty ? 0.0 : Double(repeated.values.reduce(0, +)) / Double(repeated.count)

        return repeatPct * 0.6 + min(avgRepeats, 10.0) * 10.0 * 0.4
    }

    func calculateEngagementAuthenticity(for post: Post) -> Double {
        if post.commentsList.isEmpty {
            let total = post.metrics.totalEngagements
            guard total > 0 else { return 50.0 }

            let ratio = Double(post.metrics.likes) / Double(max(post.metrics.comments, 1))
            if ratio > 100 { return 30.0 }
            if ratio > 50 { return 50.0 }
            return 70.0
        }

        let analysis = sentimentAnalyzer.analyzePostComments(post)
        var authenticity = 100.0 - analysis.spamPercentage
        authenticity += analysis.meaningfulPercentage * 0.3
        authenticity += min(Double(analysis.expertComments) * 5.0, 20.0)
        return min(max(authenticity, 0), 100.0)
    }

    struct CreatorQuality {
        let communityScore: Double
        let avgAuthenticity: Double
        let avgCommentQuality: Double
        let avgSentiment: Double
        let totalPostsAnalyzed: Int
        let repeatedCommenters: Int
    }

    func analyzeCreatorEngagementQuality(creatorId: String) -> CreatorQuality {
        let creatorPosts = posts.filter { $0.creatorId == creatorId }
        guard !creatorPosts.isEmpty else {
            return CreatorQuality(
                communityScore: 0, avgAuthenticity: 0, avgCommentQuality: 0,
                avgSentiment: 0, totalPostsAnalyzed: 0, repeatedCommenters: 0
            )
        }

        let authenticityScores = creatorPosts.map { calculateEngagementAuthenticity(for: $0) }
        let commentAnalyses = creatorPosts.map { sentimentAnalyzer.analyzePostComments($0) }

        return CreatorQuality(
            communityScore: calculateCommunityScore(creatorId: creatorId),
            avgAuthenticity: authenticityScores.mean,
            avgCommentQuality: commentAnalyses.map(\.commentQualityScore).mean,
            avgSentiment: commentAnalyses.map(\.avgSentiment).mean,
            totalPostsAnalyzed: creatorPosts.count,
            repeatedCommenters: identifyRepeatedCommenters(creatorId: creatorId).count
        )
    }
}
