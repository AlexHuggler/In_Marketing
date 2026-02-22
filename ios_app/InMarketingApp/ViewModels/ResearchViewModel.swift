import Foundation
import SwiftUI
import Combine

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
    @Published var showErrorAlert = false
    @Published var errorMessage = ""

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

    // Favorites (persisted)
    @Published var favoritedCreatorIds: Set<String> = [] {
        didSet { persistFavorites() }
    }

    // Available niches from dataset (for autocomplete)
    @Published var availableNiches: [String] = []

    // MARK: - Private

    private let dataLoader = DataLoader()
    private var currentTask: Task<Void, Never>?
    private let favoritesKey = "com.inmarketing.favoriteCreatorIds"

    // MARK: - Init

    init() {
        loadFavorites()
    }

    // MARK: - Load Sample Data

    func loadSampleData() {
        // Cancel any in-flight task
        currentTask?.cancel()
        isLoading = true

        currentTask = Task.detached { [sampleSize] in
            let (samplePosts, sampleCreators) = SampleDataGenerator.generateSampleData(
                numCreators: sampleSize,
                postsPerCreator: 15,
                commentsPerPost: 10
            )

            guard !Task.isCancelled else { return }

            await MainActor.run { [self] in
                self.posts = samplePosts
                self.creators = sampleCreators
                self.hasData = true
                self.isLoading = false
                self.rebuildAvailableNiches()
                self.generateAllReports()
                Haptics.success()
            }
        }
    }

    // MARK: - Load CSV Data

    func loadPostsCSV(content: String) {
        isLoading = true
        let newPosts = dataLoader.loadPostsFromCSV(content: content)
        posts.append(contentsOf: newPosts)
        finishDataLoad(importedCount: newPosts.count, type: "posts")
    }

    func loadCreatorsCSV(content: String) {
        isLoading = true
        let newCreators = dataLoader.loadCreatorsFromCSV(content: content)
        for c in newCreators { creators[c.id] = c }
        finishDataLoad(importedCount: newCreators.count, type: "creators")
    }

    // MARK: - Load JSON Data

    func loadJSON(data: Data) {
        isLoading = true
        let (newPosts, newCreators) = dataLoader.loadFromJSON(content: data)
        posts.append(contentsOf: newPosts)
        for c in newCreators { creators[c.id] = c }
        let total = newPosts.count + newCreators.count
        finishDataLoad(importedCount: total, type: "records")
    }

    private func finishDataLoad(importedCount: Int, type: String) {
        isLoading = false
        loadErrors = dataLoader.loadErrors

        if !loadErrors.isEmpty {
            errorMessage = "Imported \(importedCount) \(type) with warnings:\n\n" + loadErrors.joined(separator: "\n")
            showErrorAlert = true
            Haptics.warning()
        } else if importedCount == 0 {
            errorMessage = "No \(type) could be imported. Check that your file has the correct column headers."
            showErrorAlert = true
            Haptics.error()
        } else {
            Haptics.success()
        }

        hasData = !posts.isEmpty || !creators.isEmpty
        if hasData {
            rebuildAvailableNiches()
            generateAllReports()
        }
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

    // MARK: - Available Niches (for autocomplete)

    private func rebuildAvailableNiches() {
        var niches = Set<String>()
        for creator in creators.values {
            for tag in creator.nicheTags {
                niches.insert(tag.lowercased())
            }
        }
        for post in posts {
            for topic in post.topics {
                niches.insert(topic.lowercased())
            }
        }
        availableNiches = niches.sorted()
    }

    func nicheSuggestions(for query: String) -> [String] {
        guard !query.isEmpty else { return availableNiches.prefix(15).map { $0 } }
        let lower = query.lowercased()
        return availableNiches
            .filter { $0.contains(lower) }
            .prefix(10)
            .map { $0 }
    }

    // MARK: - Favorites

    func toggleFavorite(creatorId: String) {
        if favoritedCreatorIds.contains(creatorId) {
            favoritedCreatorIds.remove(creatorId)
        } else {
            favoritedCreatorIds.insert(creatorId)
            Haptics.impact()
        }
    }

    func isFavorited(_ creatorId: String) -> Bool {
        favoritedCreatorIds.contains(creatorId)
    }

    var favoritedCreators: [CreatorRankingItem] {
        creatorRankings.filter { favoritedCreatorIds.contains($0.creatorId) }
    }

    private func persistFavorites() {
        UserDefaults.standard.set(Array(favoritedCreatorIds), forKey: favoritesKey)
    }

    private func loadFavorites() {
        if let saved = UserDefaults.standard.stringArray(forKey: favoritesKey) {
            favoritedCreatorIds = Set(saved)
        }
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
