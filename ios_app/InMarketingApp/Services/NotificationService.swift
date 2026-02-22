import Foundation

/// Evaluates analytics results for high-value notification moments.
/// Uses `actor` for thread safety since report generation runs on `Task.detached`.
actor NotificationService {

    // MARK: - Storage Keys

    private static let preferencesKey = "com.inmarketing.notificationPreferences"
    private static let historyFileName = "inmarketing_notifications.json"

    // MARK: - State

    private var preferences: NotificationPreferences
    private var history: NotificationHistory

    // MARK: - Init

    init() {
        self.preferences = Self.loadPreferences()
        self.history = Self.loadHistory()
    }

    // MARK: - Public API

    /// Main entry point. Called after `generateAllReportsAsync()` completes.
    /// Scans all report results for high-value moments and returns qualified notifications.
    func evaluateReportResults(
        posts: [Post],
        creators: [String: Creator],
        creatorRankings: [CreatorRankingItem],
        whitespaceOpportunities: [WhitespaceOpportunity],
        trendingReport: ReportGenerator.TrendingReport?,
        executiveSummary: ExecutiveSummary?,
        favoritedCreatorIds: Set<String>,
        risingStars: [NicheDiscovery.RisingStar]
    ) -> [NotificationItem] {
        guard preferences.isEnabled else { return [] }
        guard !isInQuietHours() else { return [] }

        var candidates: [NotificationCandidate] = []

        if preferences.anomalyAlertsEnabled {
            candidates.append(contentsOf: detectAnomalies(posts: posts, creators: creators))
        }

        if preferences.timingAlertsEnabled, let timing = trendingReport?.bestPostingTimes {
            candidates.append(contentsOf: detectTimingOpportunity(timing: timing))
        }

        if preferences.milestoneAlertsEnabled {
            candidates.append(contentsOf: detectMilestones(
                rankings: creatorRankings,
                favoritedIds: favoritedCreatorIds,
                previousScores: history.previousCreatorScores,
                previousGrowth: history.previousGrowthRates
            ))
        }

        if preferences.featureDiscoveryEnabled {
            candidates.append(contentsOf: detectFeatureOpportunities(whitespace: whitespaceOpportunities))
        }

        // Score, filter, rate-limit
        let qualified = candidates
            .map { score(candidate: $0, favoritedIds: favoritedCreatorIds) }
            .filter { $0.valueScore >= preferences.minimumValueThreshold }
            .filter { !isDuplicate($0) }
            .filter { !isInCooldown(for: $0.eventType) }
            .sorted { $0.valueScore > $1.valueScore }

        let budget = dailyBudgetRemaining()
        let toDeliver = Array(qualified.prefix(budget))

        // Persist delivered notifications
        for item in toDeliver {
            history.items.append(item)
        }

        // Update snapshots for next comparison
        updateSnapshots(
            rankings: creatorRankings,
            avgEngagementRate: executiveSummary?.overview.averageEngagementRate ?? 0
        )

        saveHistory()

        return toDeliver
    }

    // MARK: - User Behavior Tracking

    func trackAppOpen() {
        history.totalAppOpens += 1
        saveHistory()
    }

    func trackTabVisit(_ tab: String) {
        switch tab {
        case "discovery":
            history.discoveryTabVisitCount += 1
            history.lastDiscoveryTabVisit = Date()
        case "contentIdeas":
            history.contentIdeasTabVisitCount += 1
            history.lastContentIdeasTabVisit = Date()
        default:
            break
        }
        saveHistory()
    }

    func markAsRead(_ notificationId: String) {
        if let index = history.items.firstIndex(where: { $0.id == notificationId }) {
            history.items[index].isRead = true
            saveHistory()
        }
    }

    // MARK: - Preferences

    func updatePreferences(_ prefs: NotificationPreferences) {
        preferences = prefs
        Self.savePreferences(prefs)
    }

    func getPreferences() -> NotificationPreferences {
        preferences
    }

    func getUnreadNotifications() -> [NotificationItem] {
        history.items.filter { !$0.isRead }.sorted { $0.createdAt > $1.createdAt }
    }

    func getRecentNotifications(limit: Int = 20) -> [NotificationItem] {
        Array(history.items.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
    }

    // MARK: - Anomaly Detection

    private func detectAnomalies(
        posts: [Post],
        creators: [String: Creator]
    ) -> [NotificationCandidate] {
        let analyzer = EngagementAnalyzer(posts: posts, creators: creators)
        var candidates: [NotificationCandidate] = []

        for creator in creators.values {
            let metrics = analyzer.calculateCreatorMetrics(for: creator)
            guard metrics.totalPosts >= 3 else { continue }

            let creatorPosts = posts.filter { $0.creatorId == creator.id }
            let rates = creatorPosts.map { analyzer.calculateEngagementRate(for: $0) }
            let stdDev = rates.standardDeviation
            guard stdDev > 0 else { continue }

            for (post, rate) in zip(creatorPosts, rates) {
                let zScore = (rate - metrics.avgEngagementRate) / stdDev
                guard zScore > 2.0 else { continue }

                let multiplier = rate / max(metrics.avgEngagementRate, 0.01)
                let displayName = creator.displayName.isEmpty ? creator.username : creator.displayName

                candidates.append(NotificationCandidate(
                    eventType: .engagementAnomaly,
                    title: "Engagement Spike Detected",
                    body: "\(displayName)'s post is outperforming their average by \(String(format: "%.1f", multiplier))x (\(String(format: "%.1f%%", rate)) vs. usual \(String(format: "%.1f%%", metrics.avgEngagementRate))). Worth studying what worked.",
                    deduplicationKey: "anomaly_\(creator.id)_\(post.id)",
                    relatedCreatorId: creator.id,
                    relatedPostId: post.id,
                    magnitudeScore: min(1.0, zScore / 4.0),
                    actionabilityScore: 0.8
                ))
            }
        }

        // Return only the top 2 most extreme anomalies
        return Array(candidates.sorted { $0.magnitudeScore > $1.magnitudeScore }.prefix(2))
    }

    // MARK: - Timing Opportunity Detection

    private func detectTimingOpportunity(timing: TimingAnalysis) -> [NotificationCandidate] {
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let currentDay = formatter.string(from: now)

        let topDays = timing.bestDays.prefix(2).map(\.label)
        guard topDays.contains(currentDay) else { return [] }

        for hourItem in timing.bestHours.prefix(3) {
            let hourString = hourItem.label.replacingOccurrences(of: ":00", with: "")
            guard let bestHour = Int(hourString) else { continue }
            guard abs(currentHour - bestHour) <= 2 else { continue }

            return [NotificationCandidate(
                eventType: .optimalPostingTime,
                title: "Prime Posting Window",
                body: "Your data shows \(currentDay)s at \(hourItem.label) drive \(String(format: "%.0f", hourItem.avgEngagement)) avg engagement. The next 2 hours are your sweet spot.",
                deduplicationKey: "timing_\(currentDay)_\(hourItem.label)",
                magnitudeScore: 0.7,
                actionabilityScore: 1.0
            )]
        }

        return []
    }

    // MARK: - Milestone Detection

    private func detectMilestones(
        rankings: [CreatorRankingItem],
        favoritedIds: Set<String>,
        previousScores: [String: Double],
        previousGrowth: [String: Double]
    ) -> [NotificationCandidate] {
        var candidates: [NotificationCandidate] = []

        for ranking in rankings {
            guard favoritedIds.contains(ranking.creatorId) else { continue }

            let prevScore = previousScores[ranking.creatorId] ?? 0
            let prevGrowth = previousGrowth[ranking.creatorId] ?? 0

            // Composite score crossed 75 (highly recommended)
            if ranking.compositeScore >= 75 && prevScore < 75 && prevScore > 0 {
                candidates.append(NotificationCandidate(
                    eventType: .creatorMilestone,
                    title: "Creator Milestone",
                    body: "\(ranking.displayName) just reached 'Highly Recommended' status (score: \(String(format: "%.0f", ranking.compositeScore))). Their engagement and growth are accelerating.",
                    deduplicationKey: "milestone_score_\(ranking.creatorId)",
                    relatedCreatorId: ranking.creatorId,
                    magnitudeScore: min(1.0, ranking.compositeScore / 100.0),
                    actionabilityScore: 0.6
                ))
            }

            // Growth rate crossed 10%
            if ranking.growthRate30d >= 10.0 && prevGrowth < 10.0 && prevGrowth > 0 {
                candidates.append(NotificationCandidate(
                    eventType: .creatorMilestone,
                    title: "Rising Star Alert",
                    body: "\(ranking.displayName) just crossed 10% monthly growth (now at \(String(format: "%.1f%%", ranking.growthRate30d))). They're in your favorites — might be time to reach out.",
                    deduplicationKey: "milestone_growth_\(ranking.creatorId)",
                    relatedCreatorId: ranking.creatorId,
                    magnitudeScore: min(1.0, ranking.growthRate30d / 20.0),
                    actionabilityScore: 0.6
                ))
            }
        }

        return candidates
    }

    // MARK: - Feature Discovery Detection

    private func detectFeatureOpportunities(
        whitespace: [WhitespaceOpportunity]
    ) -> [NotificationCandidate] {
        // Only trigger if user has opened app 3+ times without visiting discovery tab
        let visitsSinceLastDiscovery: Int
        if let lastVisit = history.lastDiscoveryTabVisit {
            let hoursSince = Date().timeIntervalSince(lastVisit) / 3600
            visitsSinceLastDiscovery = hoursSince > 48 ? history.totalAppOpens : 0
        } else {
            visitsSinceLastDiscovery = history.totalAppOpens
        }

        guard visitsSinceLastDiscovery >= 3 else { return [] }

        let highPriority = whitespace.filter { $0.recommendedPriority == "High" }
        guard let top = highPriority.first else { return [] }

        return [NotificationCandidate(
            eventType: .featureDiscovery,
            title: "Untapped Content Opportunity",
            body: "'\(top.topic.capitalized)' has high engagement (avg \(String(format: "%.0f", top.engagementRate))) but only \(top.creatorCount) creators covering it. Tap to see the whitespace analysis.",
            deduplicationKey: "feature_whitespace_\(top.id)",
            magnitudeScore: min(1.0, top.opportunityScore / 1000.0),
            actionabilityScore: 0.5
        )]
    }

    // MARK: - Value Scoring

    private func score(
        candidate: NotificationCandidate,
        favoritedIds: Set<String>
    ) -> NotificationItem {
        // Relevance: favorited creator = 1.0, any creator = 0.5, general = 0.6
        var relevance = candidate.relevanceScore
        if relevance == 0 {
            if let creatorId = candidate.relatedCreatorId, favoritedIds.contains(creatorId) {
                relevance = 1.0
            } else if candidate.relatedCreatorId != nil {
                relevance = 0.5
            } else {
                relevance = 0.6
            }
        }

        // Novelty: decays from 1.0 based on hours since last same-type notification
        let novelty: Double
        if let lastSimilar = history.items.last(where: { $0.eventType == candidate.eventType }) {
            let hoursSince = Date().timeIntervalSince(lastSimilar.createdAt) / 3600
            novelty = min(1.0, hoursSince / candidate.eventType.cooldownHours)
        } else {
            novelty = 1.0
        }

        let valueScore =
            candidate.magnitudeScore * 0.30 +
            novelty * 0.25 +
            relevance * 0.25 +
            candidate.actionabilityScore * 0.20

        return NotificationItem(
            id: UUID().uuidString,
            eventType: candidate.eventType,
            title: candidate.title,
            body: candidate.body,
            valueScore: valueScore,
            createdAt: Date(),
            relatedCreatorId: candidate.relatedCreatorId,
            relatedPostId: candidate.relatedPostId,
            deduplicationKey: candidate.deduplicationKey,
            magnitudeScore: candidate.magnitudeScore,
            noveltyScore: novelty,
            relevanceScore: relevance,
            actionabilityScore: candidate.actionabilityScore
        )
    }

    // MARK: - Rate Limiting

    private func dailyBudgetRemaining() -> Int {
        let todayStart = Calendar.current.startOfDay(for: Date())
        let todayCount = history.items.filter { $0.createdAt >= todayStart }.count
        return max(0, preferences.maxNotificationsPerDay - todayCount)
    }

    private func isInCooldown(for type: NotificationEventType) -> Bool {
        guard let lastOfType = history.items.last(where: { $0.eventType == type }) else {
            return false
        }
        let hoursSince = Date().timeIntervalSince(lastOfType.createdAt) / 3600
        return hoursSince < type.cooldownHours
    }

    private func isDuplicate(_ item: NotificationItem) -> Bool {
        let cutoff = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
        return history.items.contains { existing in
            existing.deduplicationKey == item.deduplicationKey &&
            existing.createdAt >= cutoff
        }
    }

    private func isInQuietHours() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        if preferences.quietHoursStart > preferences.quietHoursEnd {
            return hour >= preferences.quietHoursStart || hour < preferences.quietHoursEnd
        } else {
            return hour >= preferences.quietHoursStart && hour < preferences.quietHoursEnd
        }
    }

    // MARK: - Snapshot Updates

    private func updateSnapshots(
        rankings: [CreatorRankingItem],
        avgEngagementRate: Double
    ) {
        var scores: [String: Double] = [:]
        var growth: [String: Double] = [:]
        for r in rankings {
            scores[r.creatorId] = r.compositeScore
            growth[r.creatorId] = r.growthRate30d
        }
        history.previousCreatorScores = scores
        history.previousGrowthRates = growth
        history.previousAvgEngagementRate = avgEngagementRate
        history.lastUpdated = Date()
    }

    // MARK: - Persistence

    private static var historyFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(historyFileName)
    }

    private static func loadHistory() -> NotificationHistory {
        guard FileManager.default.fileExists(atPath: historyFileURL.path),
              let data = try? Data(contentsOf: historyFileURL) else {
            return NotificationHistory()
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(NotificationHistory.self, from: data)) ?? NotificationHistory()
    }

    private func saveHistory() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(history) else { return }
        try? data.write(to: Self.historyFileURL, options: .atomic)
    }

    private static func loadPreferences() -> NotificationPreferences {
        guard let data = UserDefaults.standard.data(forKey: preferencesKey) else {
            return NotificationPreferences()
        }
        return (try? JSONDecoder().decode(NotificationPreferences.self, from: data)) ?? NotificationPreferences()
    }

    private static func savePreferences(_ prefs: NotificationPreferences) {
        guard let data = try? JSONEncoder().encode(prefs) else { return }
        UserDefaults.standard.set(data, forKey: preferencesKey)
    }
}
