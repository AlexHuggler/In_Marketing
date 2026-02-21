import Foundation

/// Creates realistic sample data for demonstrating the influencer research tool.
struct SampleDataGenerator {

    // MARK: - Configuration

    private static let niches: [(name: String, baseEngagement: Double, volatility: Double)] = [
        ("productivity", 3.5, 0.3), ("technology", 2.8, 0.4), ("ai", 4.2, 0.5),
        ("marketing", 3.0, 0.3), ("entrepreneurship", 3.8, 0.35),
        ("personal-finance", 4.0, 0.4), ("wellness", 4.5, 0.25),
        ("fitness", 5.2, 0.3), ("cooking", 4.8, 0.2), ("travel", 4.0, 0.35),
        ("fashion", 3.5, 0.3), ("photography", 3.2, 0.25),
        ("design", 3.0, 0.3), ("leadership", 3.5, 0.35), ("career", 4.0, 0.3),
    ]

    private static let platforms: [SocialPlatform] = [.instagram, .tiktok, .twitter, .linkedin]

    private static let contentTemplates: [(text: String, media: MediaType)] = [
        ("What's the one {topic} hack that changed your life?", .text),
        ("How do you handle {challenge} in your {topic} journey?", .text),
        ("5 {topic} tips that doubled my {outcome}:", .carousel),
        ("7 mistakes I made in {topic} (and how to avoid them)", .reel),
        ("10 {topic} tools I can't live without", .image),
        ("How to master {topic} in 30 days:", .video),
        ("Step-by-step guide to {outcome}", .carousel),
        ("The complete beginner's guide to {topic}", .article),
        ("Hot take: Most {topic} advice is wrong", .text),
        ("Unpopular opinion: {topic} is overrated", .video),
        ("My {topic} journey: From zero to {outcome}", .reel),
        ("How I went from {start} to {end} in {topic}", .video),
        ("{percentage}% of people fail at {topic}. Here's why:", .image),
        ("I analyzed 1000 {topic} posts. Here's what works:", .carousel),
        ("What I wish I knew about {topic} 5 years ago", .text),
        ("My morning {topic} routine that changed everything", .reel),
    ]

    private static let firstNames = [
        "Alex", "Jordan", "Taylor", "Morgan", "Casey", "Riley", "Jamie", "Avery",
        "Quinn", "Reese", "Skyler", "Dakota", "Cameron", "Peyton", "Blake",
        "Emma", "Liam", "Sophia", "Noah", "Olivia", "James", "Ava", "William",
        "Isabella", "Oliver",
    ]

    private static let lastNames = [
        "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller",
        "Davis", "Rodriguez", "Martinez", "Chen", "Lee", "Wang", "Kim", "Patel",
        "Anderson", "Taylor", "Thomas", "Moore", "Jackson", "White", "Harris",
    ]

    private static let commentTemplates: [(text: String, isPositive: Bool)] = [
        ("This is exactly what I needed to hear! Thank you!", true),
        ("Great tips! Saving this for later.", true),
        ("Love this content. Keep it coming!", true),
        ("So helpful! I've been struggling with this.", true),
        ("Disagree. This doesn't work in real life.", false),
        ("Not sure about this one...", false),
        ("Can you elaborate on point 3?", true),
        ("This changed my perspective completely.", true),
        ("Where can I learn more about this?", true),
        ("Sharing with my team!", true),
        ("Game changer!", true),
        ("I tried this and it actually works!", true),
        ("Overrated advice tbh", false),
        ("Anyone else think this is oversimplified?", false),
        ("Finally someone talking about this!", true),
        ("Your content is always so valuable", true),
        ("Bookmarked!", true),
        ("This is why I follow you", true),
        ("fire content", true),
        ("nice", true),
    ]

    // MARK: - Generate Sample Data

    static func generateSampleData(
        numCreators: Int = 25,
        postsPerCreator: Int = 15,
        commentsPerPost: Int = 10
    ) -> (posts: [Post], creators: [String: Creator]) {
        var creators: [String: Creator] = [:]
        var posts: [Post] = []

        for i in 0..<numCreators {
            let creatorId = "creator_\(String(format: "%03d", i))"
            let firstName = firstNames[i % firstNames.count]
            let lastName = lastNames[i % lastNames.count]

            let creatorNiches = Array(niches.shuffled().prefix(Int.random(in: 1...3)))
            let primaryNiche = creatorNiches[0]

            // Tier distribution
            let tier: (String, ClosedRange<Int>)
            let tierRoll = Double.random(in: 0...1)
            if tierRoll < 0.30 { tier = ("nano", 100...999) }
            else if tierRoll < 0.65 { tier = ("micro", 1_000...9_999) }
            else if tierRoll < 0.85 { tier = ("mid", 10_000...99_999) }
            else if tierRoll < 0.97 { tier = ("macro", 100_000...999_999) }
            else { tier = ("mega", 1_000_000...5_000_000) }

            let followerCount = Int.random(in: tier.1)
            let platform = platforms.randomElement()!

            let usernameStyles = [
                "\(firstName.lowercased())\(lastName.lowercased())",
                "\(firstName.lowercased())_\(primaryNiche.name)",
                "the_\(primaryNiche.name)_pro",
            ]
            let username = usernameStyles.randomElement()!.replacingOccurrences(of: "-", with: "")

            let tierEngMod: [String: Double] = ["nano": 1.5, "micro": 1.3, "mid": 1.0, "macro": 0.7, "mega": 0.5]
            let engagementRate = primaryNiche.baseEngagement * (tierEngMod[tier.0] ?? 1.0) * Double.random(in: 0.7...1.3)

            let growth7d = Double.random(in: -1.5...3.5)
            let growth30d = Double.random(in: -3.0...12.0)

            var creator = Creator(
                id: creatorId,
                username: username,
                platform: platform,
                displayName: "\(firstName) \(lastName)",
                bio: "\(primaryNiche.name.capitalized) enthusiast | Sharing \(creatorNiches.map(\.name).joined(separator: ", ")) insights",
                followerCount: followerCount,
                followingCount: Int.random(in: 100...min(5000, followerCount)),
                nicheTags: creatorNiches.map(\.name),
                primaryNiche: primaryNiche.name,
                secondaryNiches: Array(creatorNiches.dropFirst().map(\.name)),
                totalPosts: postsPerCreator,
                avgEngagementRate: engagementRate,
                avgLikes: Double(Int(Double(followerCount) * engagementRate / 100.0 * 0.7)),
                avgComments: Double(Int(Double(followerCount) * engagementRate / 100.0 * 0.2)),
                followerGrowthRate7d: growth7d,
                followerGrowthRate30d: growth30d,
                firstTracked: Calendar.current.date(byAdding: .day, value: -30, to: Date()),
                lastUpdated: Date()
            )

            // Generate posts
            for j in 0..<postsPerCreator {
                let postId = "post_\(creatorId)_\(String(format: "%03d", j))"
                let timestamp = Calendar.current.date(
                    byAdding: .hour,
                    value: -Int.random(in: 0...(30 * 24)),
                    to: Date()
                ) ?? Date()

                let template = contentTemplates.randomElement()!
                let text = template.text
                    .replacingOccurrences(of: "{topic}", with: primaryNiche.name)
                    .replacingOccurrences(of: "{challenge}", with: ["consistency", "motivation", "time", "focus"].randomElement()!)
                    .replacingOccurrences(of: "{outcome}", with: ["results", "productivity", "success", "growth"].randomElement()!)
                    .replacingOccurrences(of: "{start}", with: ["beginner", "struggling", "confused"].randomElement()!)
                    .replacingOccurrences(of: "{end}", with: ["expert", "thriving", "successful"].randomElement()!)
                    .replacingOccurrences(of: "{percentage}", with: "\(Int.random(in: 60...95))")

                let hashtags = ["#\(creatorNiches[0].name)", "#\(["tips", "advice", "growth", "success"].randomElement()!)"]

                let engMult = max(0.2, gaussianRandom(mean: 1.0, stddev: primaryNiche.volatility))
                let platformReach: [SocialPlatform: Double] = [.tiktok: 3.0, .instagram: 1.0, .twitter: 0.8, .linkedin: 0.6]
                let baseViews = Int(Double(followerCount) * (platformReach[platform] ?? 1.0) * Double.random(in: 0.5...2.0))

                let metrics = EngagementMetrics(
                    likes: Int(Double(baseViews) * engagementRate / 100.0 * 0.7 * engMult),
                    comments: Int(Double(baseViews) * engagementRate / 100.0 * 0.15 * engMult),
                    shares: Int(Double(baseViews) * engagementRate / 100.0 * 0.1 * engMult),
                    saves: Int(Double(baseViews) * engagementRate / 100.0 * 0.05 * engMult),
                    views: baseViews
                )

                // Generate comments
                var comments: [Comment] = []
                for k in 0..<min(metrics.comments, commentsPerPost) {
                    let ct = commentTemplates.randomElement()!
                    comments.append(Comment(
                        id: "comment_\(postId)_\(String(format: "%03d", k))",
                        authorId: "user_\(Int.random(in: 1000...9999))",
                        authorUsername: "user_\(Int.random(in: 1000...9999))",
                        text: ct.text,
                        timestamp: Calendar.current.date(byAdding: .hour, value: Int.random(in: 1...48), to: timestamp) ?? timestamp,
                        likes: Int.random(in: 0...50),
                        sentimentScore: ct.isPositive ? 0.5 : -0.3
                    ))
                }

                let hoursSince = max(1.0, Date().timeIntervalSince(timestamp) / 3600.0)
                let totalEng = metrics.totalEngagements
                let eng1h: Int, eng6h: Int, eng24h: Int
                if hoursSince < 1 { eng1h = totalEng; eng6h = 0; eng24h = 0 }
                else if hoursSince < 6 { eng1h = Int(Double(totalEng) * 0.3); eng6h = totalEng; eng24h = 0 }
                else if hoursSince < 24 { eng1h = Int(Double(totalEng) * 0.2); eng6h = Int(Double(totalEng) * 0.6); eng24h = totalEng }
                else { eng1h = Int(Double(totalEng) * 0.15); eng6h = Int(Double(totalEng) * 0.4); eng24h = Int(Double(totalEng) * 0.8) }

                let post = Post(
                    id: postId,
                    creatorId: creatorId,
                    platform: platform,
                    text: text,
                    mediaType: template.media,
                    timestamp: timestamp,
                    hashtags: hashtags,
                    topics: creatorNiches.map(\.name),
                    metrics: metrics,
                    commentsList: comments,
                    engagements1h: eng1h,
                    engagements6h: eng6h,
                    engagements24h: eng24h
                )

                posts.append(post)
                creator.posts.append(post)
            }

            creators[creatorId] = creator
        }

        return (posts, creators)
    }

    // MARK: - Gaussian Random

    private static func gaussianRandom(mean: Double, stddev: Double) -> Double {
        let u1 = Double.random(in: 0.0001...1)
        let u2 = Double.random(in: 0.0001...1)
        let z = (-2.0 * log(u1)).squareRoot() * cos(2.0 * .pi * u2)
        return z * stddev + mean
    }
}
