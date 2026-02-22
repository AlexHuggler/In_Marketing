import Foundation

/// Persists posts and creators to the app's documents directory as JSON.
/// Uses Codable for type-safe round-trip serialization.
struct DataPersistence {

    private static let fileName = "inmarketing_data.json"

    private static var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(fileName)
    }

    // MARK: - Persistence Container

    struct PersistedData: Codable {
        let posts: [Post]
        let creators: [String: Creator]
        let savedAt: Date
    }

    // MARK: - Save

    static func save(posts: [Post], creators: [String: Creator]) throws {
        let container = PersistedData(posts: posts, creators: creators, savedAt: Date())
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(container)
        try data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Load

    static func load() -> PersistedData? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PersistedData.self, from: data)
    }

    // MARK: - Delete

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Has Saved Data

    static var hasSavedData: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }
}
