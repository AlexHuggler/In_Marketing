import Foundation

/// Analyzes content patterns to identify "repeatable formulas".
struct ContentPatternAnalyzer {
    let posts: [Post]

    // MARK: - Hook Detection Patterns

    private static let hookPatterns: [(ContentHook, [String])] = [
        (.question, ["\\?$", "^(what|how|why|when|where|who|which|do you|can you|have you)", "wondering"]),
        (.listicle, ["\\d+\\s+(ways|tips|things|reasons|steps|secrets|hacks|mistakes)", "here are", "top \\d+"]),
        (.howTo, ["how to", "guide to", "tutorial", "step.by.step", "learn how"]),
        (.controversial, ["hot take", "unpopular opinion", "controversial", "people don't realize", "truth about"]),
        (.story, ["story time", "let me tell you", "i remember when", "true story", "my experience"]),
        (.dataInsight, ["\\d+%", "study shows", "research", "data reveals", "statistics"]),
        (.personalExperience, ["^i ", "my journey", "what i learned", "personal", "changed my life"]),
        (.prediction, ["prediction", "will happen", "future of", "in 202\\d", "next year"]),
        (.behindScenes, ["behind the scenes", "bts", "how we", "day in the life", "process"]),
    ]

    func detectContentHook(in text: String) -> ContentHook {
        let lower = text.lowercased()

        for (hook, patterns) in Self.hookPatterns {
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(lower.startIndex..., in: lower)
                    if regex.firstMatch(in: lower, range: range) != nil {
                        return hook
                    }
                }
            }
        }
        return .other
    }

    func detectContentFormat(for post: Post) -> ContentFormat {
        if [.reel, .story].contains(post.mediaType) {
            return .shortForm
        } else if post.mediaType == .article {
            return .longForm
        } else if post.mediaType == .video {
            return .longForm
        }

        let textLength = post.text.count
        if textLength < 280 { return .shortForm }
        if textLength > 500 { return .longForm }

        let lower = post.text.lowercased()
        if lower.contains("tutorial") || lower.contains("how to") || lower.contains("learn") {
            return .educational
        }
        if lower.contains("review") || lower.contains("rating") { return .review }
        if lower.contains("vs") || lower.contains("versus") || lower.contains("comparison") {
            return .comparison
        }

        return .shortForm
    }

    // MARK: - Classification

    struct ClassifiedPost: Identifiable {
        let id: String
        let hook: String
        let format: String
        let textPreview: String
        let engagement: Int
    }

    func classifyPosts() -> [ClassifiedPost] {
        posts.map { post in
            ClassifiedPost(
                id: post.id,
                hook: detectContentHook(in: post.text).rawValue,
                format: detectContentFormat(for: post).rawValue,
                textPreview: String(post.text.prefix(100)),
                engagement: post.metrics.totalEngagements
            )
        }
    }

    // MARK: - Pattern Performance

    struct PatternPerformance {
        let hooks: [PatternStat]
        let formats: [PatternStat]
    }

    struct PatternStat: Identifiable {
        let id = UUID()
        let name: String
        let postCount: Int
        let avgEngagement: Double
        let totalEngagement: Int
    }

    func analyzePatternPerformance() -> PatternPerformance {
        var hookStats: [String: (count: Int, totalEngagement: Int)] = [:]
        var formatStats: [String: (count: Int, totalEngagement: Int)] = [:]

        for post in posts {
            let hook = detectContentHook(in: post.text).rawValue
            let format = detectContentFormat(for: post).rawValue
            let engagement = post.metrics.totalEngagements

            hookStats[hook, default: (0, 0)].count += 1
            hookStats[hook, default: (0, 0)].totalEngagement += engagement

            formatStats[format, default: (0, 0)].count += 1
            formatStats[format, default: (0, 0)].totalEngagement += engagement
        }

        let hookResults = hookStats.map { hook, stats in
            PatternStat(
                name: hook,
                postCount: stats.count,
                avgEngagement: stats.count > 0 ? Double(stats.totalEngagement) / Double(stats.count) : 0,
                totalEngagement: stats.totalEngagement
            )
        }.sorted { $0.avgEngagement > $1.avgEngagement }

        let formatResults = formatStats.map { fmt, stats in
            PatternStat(
                name: fmt,
                postCount: stats.count,
                avgEngagement: stats.count > 0 ? Double(stats.totalEngagement) / Double(stats.count) : 0,
                totalEngagement: stats.totalEngagement
            )
        }.sorted { $0.avgEngagement > $1.avgEngagement }

        return PatternPerformance(hooks: hookResults, formats: formatResults)
    }

    // MARK: - Winning Formulas

    func identifyWinningFormulas(minPosts: Int = 3) -> [ContentTaxonomy] {
        var formulaStats: [String: (posts: [Post], totalEngagement: Int)] = [:]

        for post in posts {
            let hook = detectContentHook(in: post.text)
            let format = detectContentFormat(for: post)
            let themes = post.topics.prefix(2).sorted()
            let themeKey = themes.isEmpty ? "general" : themes.joined(separator: ",")
            let key = "\(hook.rawValue)|\(format.rawValue)|\(themeKey)"

            var stats = formulaStats[key] ?? (posts: [], totalEngagement: 0)
            stats.posts.append(post)
            stats.totalEngagement += post.metrics.totalEngagements
            formulaStats[key] = stats
        }

        let overallAvg: Double = posts.isEmpty ? 0 :
            Double(posts.reduce(0) { $0 + $1.metrics.totalEngagements }) / Double(posts.count)

        return formulaStats.compactMap { key, stats in
            guard stats.posts.count >= minPosts else { return nil }

            let parts = key.split(separator: "|")
            guard parts.count == 3 else { return nil }
            let hookStr = String(parts[0])
            let formatStr = String(parts[1])
            let themes = String(parts[2]).split(separator: ",").map(String.init)

            let avgEngagement = Double(stats.totalEngagement) / Double(stats.posts.count)
            let successCount = stats.posts.filter { Double($0.metrics.totalEngagements) > overallAvg }.count
            let successRate = (Double(successCount) / Double(stats.posts.count)) * 100.0

            return ContentTaxonomy(
                id: key,
                name: "\(hookStr.capitalized) \(formatStr.capitalized)",
                description: "Posts using \(hookStr) hook with \(formatStr) format about \(themes.joined(separator: ", "))",
                hookTypes: ContentHook(rawValue: hookStr).map { [$0] } ?? [],
                formats: ContentFormat(rawValue: formatStr).map { [$0] } ?? [],
                themes: themes,
                avgEngagementRate: avgEngagement,
                totalPostsAnalyzed: stats.posts.count,
                successRate: successRate,
                examplePosts: Array(stats.posts.prefix(3).map(\.id))
            )
        }.sorted { $0.avgEngagementRate > $1.avgEngagementRate }
    }

    // MARK: - Content Template Generation

    func generateContentTemplate(for formula: ContentTaxonomy) -> String {
        guard let hook = formula.hookTypes.first else {
            return "Create content about \(formula.themes.joined(separator: ", ")) using an engaging approach"
        }

        let themes = formula.themes.joined(separator: ", ")

        switch hook {
        case .question:
            return "[Ask engaging question about \(themes)]\n\nHere's what I've learned...\n\n[3-5 key points]\n\nWhat do you think? Drop your thoughts below!"
        case .listicle:
            return "[Number] \(themes) tips that will change your [outcome]:\n\n1. [Tip 1]\n2. [Tip 2]\n3. [Tip 3]\n...\n\nWhich one are you trying first?"
        case .howTo:
            return "How to [achieve goal] with \(themes):\n\nStep 1: [Action]\nStep 2: [Action]\nStep 3: [Action]\n\nSave this for later!"
        case .controversial:
            return "Hot take: [Controversial opinion about \(themes)]\n\nHere's why I believe this...\n\n[Supporting points]\n\nAgree or disagree?"
        case .story:
            return "Story time: [Personal experience with \(themes)]\n\n[Beginning]\n[Challenge]\n[Resolution]\n[Lesson learned]\n\nHas this happened to you?"
        case .dataInsight:
            return "[Surprising statistic about \(themes)]\n\nHere's what this means for you:\n\n[3 implications]\n\nShare if this surprised you!"
        case .personalExperience:
            return "My \(themes) journey:\n\n[Where I started]\n[What I learned]\n[Where I am now]\n\nWhat's your story?"
        default:
            return "Create content about \(themes) using a \(hook.displayName) approach"
        }
    }
}
