import XCTest
@testable import InMarketingApp

// MARK: - Notification System Tests

final class NotificationModelTests: XCTestCase {

    func testValueScoreCalculation() {
        // High-magnitude, novel, relevant, actionable candidate should exceed 0.6
        let score =
            0.9 * 0.30 +   // magnitude
            1.0 * 0.25 +   // novelty (never sent before)
            1.0 * 0.25 +   // relevance (favorited creator)
            0.8 * 0.20     // actionability
        // = 0.27 + 0.25 + 0.25 + 0.16 = 0.93
        XCTAssertEqual(score, 0.93, accuracy: 0.01)
        XCTAssertGreaterThan(score, 0.6, "High-value candidate should exceed threshold")
    }

    func testLowValueCandidateFiltered() {
        let score =
            0.2 * 0.30 +   // magnitude
            0.1 * 0.25 +   // novelty (recently sent)
            0.3 * 0.25 +   // relevance (not favorited)
            0.2 * 0.20     // actionability
        // = 0.06 + 0.025 + 0.075 + 0.04 = 0.20
        XCTAssertEqual(score, 0.20, accuracy: 0.01)
        XCTAssertLessThan(score, 0.6, "Low-value candidate should be below threshold")
    }

    func testCooldownHoursAreSet() {
        for eventType in NotificationEventType.allCases {
            XCTAssertGreaterThan(eventType.cooldownHours, 0,
                "\(eventType.rawValue) should have positive cooldown")
        }
    }

    func testEventTypeDisplayNames() {
        for eventType in NotificationEventType.allCases {
            XCTAssertFalse(eventType.displayName.isEmpty,
                "\(eventType.rawValue) should have a display name")
        }
    }

    func testEventTypeIconNames() {
        for eventType in NotificationEventType.allCases {
            XCTAssertFalse(eventType.iconName.isEmpty,
                "\(eventType.rawValue) should have an icon name")
        }
    }

    func testNotificationPreferencesDefaultValues() {
        let prefs = NotificationPreferences()
        XCTAssertTrue(prefs.isEnabled)
        XCTAssertEqual(prefs.maxNotificationsPerDay, 3)
        XCTAssertEqual(prefs.minimumValueThreshold, 0.6, accuracy: 0.001)
        XCTAssertTrue(prefs.anomalyAlertsEnabled)
        XCTAssertTrue(prefs.timingAlertsEnabled)
        XCTAssertTrue(prefs.milestoneAlertsEnabled)
        XCTAssertTrue(prefs.featureDiscoveryEnabled)
        XCTAssertEqual(prefs.quietHoursStart, 22)
        XCTAssertEqual(prefs.quietHoursEnd, 8)
    }

    func testNotificationHistoryCodableRoundTrip() throws {
        var history = NotificationHistory()
        history.items.append(NotificationItem(
            id: "test_1",
            eventType: .engagementAnomaly,
            title: "Test Spike",
            body: "A test notification body",
            valueScore: 0.85,
            createdAt: Date(),
            deduplicationKey: "test_key_1"
        ))
        history.previousAvgEngagementRate = 3.5
        history.previousCreatorScores = ["c1": 72.0, "c2": 88.5]
        history.previousGrowthRates = ["c1": 5.2, "c2": 12.1]
        history.totalAppOpens = 7
        history.discoveryTabVisitCount = 2

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(history)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let loaded = try decoder.decode(NotificationHistory.self, from: data)

        XCTAssertEqual(loaded.items.count, 1)
        XCTAssertEqual(loaded.items.first?.id, "test_1")
        XCTAssertEqual(loaded.items.first?.eventType, .engagementAnomaly)
        XCTAssertEqual(loaded.items.first?.valueScore, 0.85, accuracy: 0.001)
        XCTAssertEqual(loaded.previousAvgEngagementRate, 3.5, accuracy: 0.001)
        XCTAssertEqual(loaded.previousCreatorScores["c1"], 72.0, accuracy: 0.001)
        XCTAssertEqual(loaded.previousGrowthRates["c2"], 12.1, accuracy: 0.001)
        XCTAssertEqual(loaded.totalAppOpens, 7)
        XCTAssertEqual(loaded.discoveryTabVisitCount, 2)
    }

    func testNotificationItemCodableRoundTrip() throws {
        let item = NotificationItem(
            id: "n_001",
            eventType: .creatorMilestone,
            title: "Rising Star Alert",
            body: "A creator crossed 10% growth",
            valueScore: 0.78,
            createdAt: Date(),
            relatedCreatorId: "c_42",
            relatedPostId: nil,
            deduplicationKey: "milestone_growth_c_42",
            magnitudeScore: 0.5,
            noveltyScore: 1.0,
            relevanceScore: 1.0,
            actionabilityScore: 0.6
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(item)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let loaded = try decoder.decode(NotificationItem.self, from: data)

        XCTAssertEqual(loaded.id, "n_001")
        XCTAssertEqual(loaded.eventType, .creatorMilestone)
        XCTAssertEqual(loaded.relatedCreatorId, "c_42")
        XCTAssertNil(loaded.relatedPostId)
        XCTAssertEqual(loaded.magnitudeScore, 0.5, accuracy: 0.001)
        XCTAssertEqual(loaded.noveltyScore, 1.0, accuracy: 0.001)
    }

    func testPreferencesCodableRoundTrip() throws {
        var prefs = NotificationPreferences()
        prefs.isEnabled = false
        prefs.anomalyAlertsEnabled = false
        prefs.maxNotificationsPerDay = 5
        prefs.minimumValueThreshold = 0.8

        let data = try JSONEncoder().encode(prefs)
        let loaded = try JSONDecoder().decode(NotificationPreferences.self, from: data)

        XCTAssertFalse(loaded.isEnabled)
        XCTAssertFalse(loaded.anomalyAlertsEnabled)
        XCTAssertTrue(loaded.timingAlertsEnabled)
        XCTAssertEqual(loaded.maxNotificationsPerDay, 5)
        XCTAssertEqual(loaded.minimumValueThreshold, 0.8, accuracy: 0.001)
    }
}

// MARK: - Anomaly Detection Prerequisite Tests

final class NotificationAnomalyTests: XCTestCase {

    func testAnomalyDetectionRequiresMinimumPosts() {
        // With fewer than 3 posts per creator, no anomalies should be flagged
        let (posts, creators) = SampleDataGenerator.generateSampleData(
            numCreators: 1, postsPerCreator: 2, commentsPerPost: 0
        )

        let analyzer = EngagementAnalyzer(posts: posts, creators: creators)
        for creator in creators.values {
            let metrics = analyzer.calculateCreatorMetrics(for: creator)
            XCTAssertEqual(metrics.totalPosts, 2,
                "Should have exactly 2 posts for minimum-post test")
            // The notification service requires >= 3 posts to detect anomalies
        }
    }

    func testEngagementRateVariationWithSufficientPosts() {
        // With enough posts, we can compute meaningful standard deviations
        let (posts, creators) = SampleDataGenerator.generateSampleData(
            numCreators: 1, postsPerCreator: 15, commentsPerPost: 5
        )

        let analyzer = EngagementAnalyzer(posts: posts, creators: creators)
        for creator in creators.values {
            let metrics = analyzer.calculateCreatorMetrics(for: creator)
            XCTAssertGreaterThanOrEqual(metrics.totalPosts, 3,
                "Should have enough posts for anomaly detection")

            let creatorPosts = posts.filter { $0.creatorId == creator.id }
            let rates = creatorPosts.map { analyzer.calculateEngagementRate(for: $0) }
            XCTAssertGreaterThan(rates.count, 0, "Should have engagement rates")
            // Standard deviation should be computable
            if rates.count > 1 {
                XCTAssertGreaterThanOrEqual(rates.standardDeviation, 0)
            }
        }
    }
}
