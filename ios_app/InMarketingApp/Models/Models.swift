import Foundation

// MARK: - Enums

enum MediaType: String, Codable, CaseIterable, Identifiable {
    case text, image, video, carousel, story, reel, live, article, thread
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum SocialPlatform: String, Codable, CaseIterable, Identifiable {
    case instagram, tiktok, twitter, linkedin, youtube, facebook, threads, other
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    var iconName: String {
        switch self {
        case .instagram: return "camera.circle.fill"
        case .tiktok: return "play.rectangle.fill"
        case .twitter: return "bubble.left.fill"
        case .linkedin: return "briefcase.fill"
        case .youtube: return "play.circle.fill"
        case .facebook: return "person.2.circle.fill"
        case .threads: return "at.circle.fill"
        case .other: return "globe"
        }
    }
}

enum ContentHook: String, Codable, CaseIterable, Identifiable {
    case question, controversial, listicle, howTo = "how_to", story
    case dataInsight = "data_insight", personalExperience = "personal_experience"
    case trendCommentary = "trend_commentary", prediction
    case behindScenes = "behind_scenes", challenge, giveaway
    case collaboration, userGenerated = "user_generated", other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .howTo: return "How-To"
        case .dataInsight: return "Data Insight"
        case .personalExperience: return "Personal Experience"
        case .trendCommentary: return "Trend Commentary"
        case .behindScenes: return "Behind the Scenes"
        case .userGenerated: return "User Generated"
        default: return rawValue.capitalized
        }
    }
}

enum ContentFormat: String, Codable, CaseIterable, Identifiable {
    case shortForm = "short_form", longForm = "long_form"
    case educational, entertainment, newsUpdate = "news_update"
    case tutorial, review, comparison, interview
    case podcastClip = "podcast_clip", infographic
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .shortForm: return "Short Form"
        case .longForm: return "Long Form"
        case .newsUpdate: return "News Update"
        case .podcastClip: return "Podcast Clip"
        default: return rawValue.capitalized
        }
    }
}

// MARK: - Comment

struct Comment: Identifiable, Codable {
    let id: String
    let authorId: String
    let authorUsername: String
    let text: String
    let timestamp: Date
    var likes: Int = 0
    var repliesCount: Int = 0
    var sentimentScore: Double = 0.0
    var isExpert: Bool = false
    var isCreatorReply: Bool = false

    enum CodingKeys: String, CodingKey {
        case id = "comment_id"
        case authorId = "author_id"
        case authorUsername = "author_username"
        case text, timestamp, likes
        case repliesCount = "replies_count"
        case sentimentScore = "sentiment_score"
        case isExpert = "is_expert"
        case isCreatorReply = "is_creator_reply"
    }
}

// MARK: - Engagement Metrics

struct EngagementMetrics: Codable {
    var likes: Int = 0
    var comments: Int = 0
    var shares: Int = 0
    var saves: Int = 0
    var views: Int = 0
    var impressions: Int = 0
    var reach: Int = 0
    var clicks: Int = 0

    var engagementRate: Double = 0.0
    var engagementVelocity: Double = 0.0
    var viralCoefficient: Double = 0.0
    var saveRate: Double = 0.0
    var commentQualityScore: Double = 0.0

    var totalEngagements: Int {
        likes + comments + shares + saves
    }

    func calculateEngagementRate(audienceSize: Int) -> Double {
        guard audienceSize > 0 else { return 0.0 }
        return (Double(totalEngagements) / Double(audienceSize)) * 100.0
    }
}

// MARK: - Post

struct Post: Identifiable, Codable {
    let id: String
    let creatorId: String
    let platform: SocialPlatform

    var text: String
    var mediaType: MediaType
    var timestamp: Date
    var url: String = ""

    var hashtags: [String] = []
    var mentions: [String] = []
    var links: [String] = []
    var topics: [String] = []
    var nicheTags: [String] = []

    var hookType: ContentHook?
    var contentFormat: ContentFormat?

    var metrics: EngagementMetrics = EngagementMetrics()
    var commentsList: [Comment] = []

    var engagements1h: Int = 0
    var engagements6h: Int = 0
    var engagements24h: Int = 0
    var engagements48h: Int = 0

    var isSponsored: Bool = false
    var isCollaboration: Bool = false
    var collaborationPartners: [String] = []

    var engagementVelocity: Double {
        if engagements24h > 0 { return Double(engagements24h) / 24.0 }
        return Double(metrics.totalEngagements) / 24.0
    }

    var hashtagString: String {
        hashtags.joined(separator: ", ")
    }

    enum CodingKeys: String, CodingKey {
        case id = "post_id"
        case creatorId = "creator_id"
        case platform, text
        case mediaType = "media_type"
        case timestamp, url, hashtags, mentions, links, topics
        case nicheTags = "niche_tags"
        case hookType = "hook_type"
        case contentFormat = "content_format"
        case metrics
        case commentsList = "comments_list"
        case engagements1h = "engagements_1h"
        case engagements6h = "engagements_6h"
        case engagements24h = "engagements_24h"
        case engagements48h = "engagements_48h"
        case isSponsored = "is_sponsored"
        case isCollaboration = "is_collaboration"
        case collaborationPartners = "collaboration_partners"
    }
}

// MARK: - Creator Growth Metrics

struct CreatorGrowthMetrics: Codable {
    let date: Date
    let followerCount: Int
    let followingCount: Int
    let postCount: Int
    let avgEngagementRate: Double
}

// MARK: - Creator

struct Creator: Identifiable, Codable {
    let id: String
    let username: String
    let platform: SocialPlatform

    var displayName: String = ""
    var bio: String = ""
    var profileUrl: String = ""

    var followerCount: Int = 0
    var followingCount: Int = 0

    var nicheTags: [String] = []
    var primaryNiche: String = ""
    var secondaryNiches: [String] = []

    var totalPosts: Int = 0
    var avgEngagementRate: Double = 0.0
    var avgLikes: Double = 0.0
    var avgComments: Double = 0.0
    var avgShares: Double = 0.0
    var avgSaves: Double = 0.0

    var followerGrowthRate7d: Double = 0.0
    var followerGrowthRate30d: Double = 0.0
    var growthHistory: [CreatorGrowthMetrics] = []

    var engagementQualityScore: Double = 0.0
    var audienceAuthenticityScore: Double = 0.0
    var contentConsistencyScore: Double = 0.0

    var collaborationRate: Double = 0.0
    var frequentCollaborators: [String] = []

    var firstTracked: Date?
    var lastUpdated: Date?
    var posts: [Post] = []

    var nicheString: String {
        let niches = [primaryNiche] + secondaryNiches
        return niches.filter { !$0.isEmpty }.joined(separator: " | ")
    }

    var isMicroInfluencer: Bool {
        (1_000...100_000).contains(followerCount)
    }

    var isNanoInfluencer: Bool {
        followerCount < 1_000
    }

    var tier: String {
        switch followerCount {
        case 1_000_000...: return "Mega (1M+)"
        case 100_000...: return "Macro (100K-1M)"
        case 10_000...: return "Mid-tier (10K-100K)"
        case 1_000...: return "Micro (1K-10K)"
        default: return "Nano (<1K)"
        }
    }

    var formattedFollowerCount: String {
        if followerCount >= 1_000_000 {
            return String(format: "%.1fM", Double(followerCount) / 1_000_000)
        } else if followerCount >= 1_000 {
            return String(format: "%.1fK", Double(followerCount) / 1_000)
        }
        return "\(followerCount)"
    }

    enum CodingKeys: String, CodingKey {
        case id = "creator_id"
        case username, platform
        case displayName = "display_name"
        case bio
        case profileUrl = "profile_url"
        case followerCount = "follower_count"
        case followingCount = "following_count"
        case nicheTags = "niche_tags"
        case primaryNiche = "primary_niche"
        case secondaryNiches = "secondary_niches"
        case totalPosts = "total_posts"
        case avgEngagementRate = "avg_engagement_rate"
        case avgLikes = "avg_likes"
        case avgComments = "avg_comments"
        case avgShares = "avg_shares"
        case avgSaves = "avg_saves"
        case followerGrowthRate7d = "follower_growth_rate_7d"
        case followerGrowthRate30d = "follower_growth_rate_30d"
        case growthHistory = "growth_history"
        case engagementQualityScore = "engagement_quality_score"
        case audienceAuthenticityScore = "audience_authenticity_score"
        case contentConsistencyScore = "content_consistency_score"
        case collaborationRate = "collaboration_rate"
        case frequentCollaborators = "frequent_collaborators"
        case firstTracked = "first_tracked"
        case lastUpdated = "last_updated"
        case posts
    }
}

// MARK: - Content Taxonomy

struct ContentTaxonomy: Identifiable {
    let id: String
    let name: String
    let description: String

    var hookTypes: [ContentHook] = []
    var formats: [ContentFormat] = []
    var themes: [String] = []

    var avgEngagementRate: Double = 0.0
    var totalPostsAnalyzed: Int = 0
    var successRate: Double = 0.0
    var examplePosts: [String] = []

    var formulaDescription: String {
        let hooks = hookTypes.map(\.displayName).joined(separator: ", ")
        let fmts = formats.map(\.displayName).joined(separator: ", ")
        return "Hook: \(hooks) | Format: \(fmts) | Themes: \(themes.joined(separator: ", "))"
    }
}

// MARK: - Trending Topic

struct TrendingTopic: Identifiable {
    let id = UUID()
    let topic: String
    let platform: SocialPlatform

    var postCount: Int = 0
    var totalEngagement: Int = 0
    var avgEngagementRate: Double = 0.0
    var growthRate: Double = 0.0

    var firstSeen: Date?
    var peakDate: Date?

    var relatedHashtags: [String] = []
    var topCreators: [String] = []

    var category: String = ""
    var isEvergreen: Bool = false
    var estimatedLifespanDays: Int = 0
}

// MARK: - Whitespace Opportunity

struct WhitespaceOpportunity: Identifiable {
    let id: String
    let topic: String
    let niche: String

    var searchVolume: Int = 0
    var engagementRate: Double = 0.0
    var audienceInterestScore: Double = 0.0

    var creatorCount: Int = 0
    var postFrequency: Double = 0.0
    var competitionScore: Double = 0.0

    var opportunityScore: Double = 0.0
    var recommendedPriority: String = ""

    var suggestedHooks: [ContentHook] = []
    var suggestedFormats: [ContentFormat] = []
    var exampleAngles: [String] = []
}

// MARK: - Collaboration Target

struct CollaborationTarget: Identifiable {
    let id: String
    let creatorName: String
    let platform: SocialPlatform

    var nicheAlignmentScore: Double = 0.0
    var audienceOverlapScore: Double = 0.0
    var engagementQualityScore: Double = 0.0
    var overallFitScore: Double = 0.0

    var followerCount: Int = 0
    var engagementRate: Double = 0.0
    var growthRate: Double = 0.0

    var previousCollaborations: Int = 0
    var collaborationSuccessRate: Double = 0.0

    var contactMethod: String = ""
    var notes: String = ""
}

// MARK: - Report Types

struct ExecutiveSummary {
    let reportDate: Date
    let overview: OverviewMetrics
    let topCreators: [CreatorRankingItem]
    let fastestGrowing: [GrowthItem]
    let topHashtags: [HashtagItem]
    let trendingTopics: [TrendItem]
    let winningFormulas: [FormulaItem]
    let whitespaceOpportunities: [WhitespaceItem]
    let recommendations: [String]
}

struct OverviewMetrics {
    let totalPostsAnalyzed: Int
    let totalCreatorsTracked: Int
    let averageEngagementRate: Double
    let topEngagementRate: Double
}

struct CreatorRankingItem: Identifiable {
    let id = UUID()
    let creatorId: String
    let username: String
    let displayName: String
    let platform: SocialPlatform
    let tier: String
    let followerCount: Int
    let primaryNiche: String
    let allNiches: String
    let avgEngagementRate: Double
    let bestEngagementRate: Double
    let consistencyScore: Double
    let growthRate7d: Double
    let growthRate30d: Double
    let authenticityScore: Double
    let communityScore: Double
    let commentQuality: Double
    let compositeScore: Double
    let postsAnalyzed: Int
}

struct GrowthItem: Identifiable {
    let id = UUID()
    let name: String
    let growthRate: Double
    let followers: Int
}

struct HashtagItem: Identifiable {
    let id = UUID()
    let hashtag: String
    let postCount: Int
    let totalEngagement: Int
    let avgEngagement: Double
    let avgEngagementRate: Double
    let avgLikes: Double
    let avgComments: Double
}

struct TrendItem: Identifiable {
    let id = UUID()
    let topic: String
    let growthRate: Double
    let postCount: Int
    let avgEngagement: Double
}

struct FormulaItem: Identifiable {
    let id = UUID()
    let formula: String
    let description: String
    let successRate: Double
    let avgEngagement: Double
}

struct WhitespaceItem: Identifiable {
    let id = UUID()
    let topic: String
    let opportunityScore: Double
    let creatorCount: Int
    let priority: String
}

struct ContentIdea: Identifiable {
    let id = UUID()
    let formulaName: String
    let description: String
    let hookType: String
    let format: String
    let themes: [String]
    let successRate: Double
    let avgEngagement: Double
    let postsUsingFormula: Int
    let template: String
    let isWhitespaceOpportunity: Bool
    let opportunityScore: Double
}

struct CollaborationReportItem: Identifiable {
    let id = UUID()
    let creatorId: String
    let name: String
    let platform: SocialPlatform
    let followers: Int
    let engagementRate: Double
    let growthRate: Double
    let nicheAlignmentScore: Double
    let engagementQualityScore: Double
    let overallFitScore: Double
    let recommendation: String
}

struct TimingAnalysis {
    let bestDays: [TimingItem]
    let bestHours: [TimingItem]
}

struct TimingItem: Identifiable {
    let id = UUID()
    let label: String
    let avgEngagement: Double
    let postCount: Int
}
