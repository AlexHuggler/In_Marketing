import Foundation

// MARK: - Notification Event Type

enum NotificationEventType: String, Codable, CaseIterable {
    case engagementAnomaly
    case optimalPostingTime
    case creatorMilestone
    case featureDiscovery

    var displayName: String {
        switch self {
        case .engagementAnomaly: return "Engagement Spike"
        case .optimalPostingTime: return "Posting Window"
        case .creatorMilestone: return "Creator Milestone"
        case .featureDiscovery: return "Content Opportunity"
        }
    }

    var iconName: String {
        switch self {
        case .engagementAnomaly: return "chart.line.uptrend.xyaxis"
        case .optimalPostingTime: return "clock.badge.checkmark"
        case .creatorMilestone: return "star.circle.fill"
        case .featureDiscovery: return "sparkles"
        }
    }

    var cooldownHours: Double {
        switch self {
        case .engagementAnomaly: return 4
        case .optimalPostingTime: return 168 // 7 days
        case .creatorMilestone: return 24
        case .featureDiscovery: return 72
        }
    }
}

// MARK: - Notification Item

struct NotificationItem: Identifiable, Codable {
    let id: String
    let eventType: NotificationEventType
    let title: String
    let body: String
    let valueScore: Double
    let createdAt: Date
    var isRead: Bool = false

    var relatedCreatorId: String?
    var relatedPostId: String?
    var deduplicationKey: String

    var magnitudeScore: Double = 0
    var noveltyScore: Double = 0
    var relevanceScore: Double = 0
    var actionabilityScore: Double = 0
}

// MARK: - Notification Preferences

struct NotificationPreferences: Codable {
    var isEnabled: Bool = true
    var anomalyAlertsEnabled: Bool = true
    var timingAlertsEnabled: Bool = true
    var milestoneAlertsEnabled: Bool = true
    var featureDiscoveryEnabled: Bool = true
    var maxNotificationsPerDay: Int = 3
    var quietHoursStart: Int = 22
    var quietHoursEnd: Int = 8
    var minimumValueThreshold: Double = 0.6
}

// MARK: - Notification History

struct NotificationHistory: Codable {
    var items: [NotificationItem] = []
    var lastUpdated: Date = Date()

    var discoveryTabVisitCount: Int = 0
    var contentIdeasTabVisitCount: Int = 0
    var totalAppOpens: Int = 0
    var lastDiscoveryTabVisit: Date?
    var lastContentIdeasTabVisit: Date?

    var previousCreatorScores: [String: Double] = [:]
    var previousGrowthRates: [String: Double] = [:]
    var previousAvgEngagementRate: Double = 0
}

// MARK: - Notification Candidate (internal, pre-scoring)

struct NotificationCandidate {
    let eventType: NotificationEventType
    let title: String
    let body: String
    let deduplicationKey: String
    var relatedCreatorId: String?
    var relatedPostId: String?
    var magnitudeScore: Double = 0
    var noveltyScore: Double = 0
    var relevanceScore: Double = 0
    var actionabilityScore: Double = 0
}
