import Foundation
import SwiftUI

/// Main view model that orchestrates all influencer research functionality.
@MainActor
class ResearchViewModel: ObservableObject {

    // MARK: - Published State

    @Published var posts: [Post] = []
    @Published var creators: [String: Creator] = [:]
    @Published var targetNiches: [String] = ["productivity", "ai", "marketing"]
    @Published var isLoading = false
    @Published var hasData = false
    @Published var loadErrors: [String] = []

    // Report caches
    @Published var executiveSummary: ExecutiveSummary?
    @Published var creatorRankings: [CreatorRankingItem] = []
    @Published var contentIdeas: [ContentIdea] = []
    @Published var collaborationTargets: [CollaborationReportItem] = []
    @Published var trendingReport: ReportGenerator.TrendingReport?
    @Published var whitespaceOpportunities: [WhitespaceOpportunity] = []
    @Published var nicheRankings: [NicheDiscovery.RankedCreator] = []
    @Published var risingStars: [NicheDiscovery.RisingStar] = []

    // Settings
    @Published var sampleSize: Int = 25
    @Published var nicheSearchText: String = ""
    @Published var selectedPlatformFilter: SocialPlatform?
    @Published var rankingMethod: String = "composite"

    // MARK: - Data Loader

    private let dataLoader = DataLoader()

    // MARK: - Load Sample Data

    func loadSampleData() {
        isLoading = true

        // Run on background to keep UI responsive
        Task.detached { [sampleSize] in
            let (samplePosts, sampleCreators) = SampleDataGenerator.generateSampleData(
                numCreators: sampleSize,
                postsPerCreator: 15,
                commentsPerPost: 10
            )

            await MainActor.run { [self] in
                self.posts = samplePosts
                self.creators = sampleCreators
                self.hasData = true
                self.isLoading = false
                self.generateAllReports()
            }
        }
    }

    // MARK: - Load CSV Data

    func loadPostsCSV(content: String) {
        let newPosts = dataLoader.loadPostsFromCSV(content: content)
        posts.append(contentsOf: newPosts)
        loadErrors = dataLoader.loadErrors
        hasData = !posts.isEmpty || !creators.isEmpty
        if hasData { generateAllReports() }
    }

    func loadCreatorsCSV(content: String) {
        let newCreators = dataLoader.loadCreatorsFromCSV(content: content)
        for c in newCreators { creators[c.id] = c }
        loadErrors = dataLoader.loadErrors
        hasData = !posts.isEmpty || !creators.isEmpty
        if hasData { generateAllReports() }
    }

    // MARK: - Load JSON Data

    func loadJSON(data: Data) {
        let (newPosts, newCreators) = dataLoader.loadFromJSON(content: data)
        posts.append(contentsOf: newPosts)
        for c in newCreators { creators[c.id] = c }
        loadErrors = dataLoader.loadErrors
        hasData = !posts.isEmpty || !creators.isEmpty
        if hasData { generateAllReports() }
    }

    // MARK: - Export

    func exportJSON() -> Data? {
        dataLoader.posts = posts
        dataLoader.creators = creators
        return dataLoader.exportToJSON()
    }

    // MARK: - Report Generation

    func generateAllReports() {
        let generator = ReportGenerator(
            posts: posts, creators: creators, targetNiches: targetNiches
        )

        executiveSummary = generator.generateExecutiveSummary()
        creatorRankings = generator.generateCreatorRankings()
        contentIdeas = generator.generateContentIdeas()
        collaborationTargets = generator.generateCollaborationTargets()
        trendingReport = generator.generateTrendingReport()

        let ws = WhitespaceAnalyzer(posts: posts, creators: creators)
        whitespaceOpportunities = ws.identifyWhitespaceOpportunities()

        refreshNicheDiscovery()
    }

    // MARK: - Niche Discovery

    func refreshNicheDiscovery() {
        let niches = nicheSearchText.isEmpty ? targetNiches :
            nicheSearchText.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }

        let discovery = NicheDiscovery(creators: creators, posts: posts)

        nicheRankings = discovery.rankCreatorsInNiche(
            niches: niches,
            rankingMethod: rankingMethod,
            platforms: selectedPlatformFilter.map { [$0] }
        )

        risingStars = discovery.findRisingStars(niches: niches)
    }

    // MARK: - Update Niches

    func updateTargetNiches(_ nichesString: String) {
        targetNiches = nichesString.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if hasData { generateAllReports() }
    }

    // MARK: - Helpers

    func creator(for id: String) -> Creator? {
        creators[id]
    }

    func posts(for creatorId: String) -> [Post] {
        posts.filter { $0.creatorId == creatorId }
    }

    var creatorsArray: [Creator] {
        Array(creators.values).sorted { $0.followerCount > $1.followerCount }
    }

    var totalEngagements: Int {
        posts.reduce(0) { $0 + $1.metrics.totalEngagements }
    }

    var averageEngagementRate: Double {
        executiveSummary?.overview.averageEngagementRate ?? 0
    }
}
