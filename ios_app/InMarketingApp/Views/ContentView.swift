import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: ResearchViewModel

    var body: some View {
        Group {
            if viewModel.hasData {
                MainTabView()
            } else {
                WelcomeView()
            }
        }
    }
}

// MARK: - Welcome / Onboarding

struct WelcomeView: View {
    @EnvironmentObject var viewModel: ResearchViewModel
    @State private var showFileImporter = false
    @State private var importType = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.blue)

                VStack(spacing: 8) {
                    Text("Influencer Research")
                        .font(.largeTitle.bold())
                    Text("Content Market Research Tool")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    Text("Track engagement metrics, discover trending topics, find top voices by niche, and identify content patterns for actionable marketing decisions.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                VStack(spacing: 16) {
                    Button {
                        viewModel.loadSampleData()
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Load Sample Data")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        importType = "posts"
                        showFileImporter = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                            Text("Import Posts CSV")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        importType = "creators"
                        showFileImporter = true
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Import Creators CSV")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)

                if viewModel.isLoading {
                    ProgressView("Generating sample data...")
                        .padding()
                }

                Spacer()
            }
            .padding()
            .navigationTitle("")
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.commaSeparatedText, .json]) { result in
                handleFileImport(result)
            }
        }
    }

    private func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            if let content = try? String(contentsOf: url, encoding: .utf8) {
                if url.pathExtension == "json", let data = content.data(using: .utf8) {
                    viewModel.loadJSON(data: data)
                } else if importType == "posts" {
                    viewModel.loadPostsCSV(content: content)
                } else {
                    viewModel.loadCreatorsCSV(content: content)
                }
            }
        case .failure:
            break
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }

            CreatorRankingsView()
                .tabItem {
                    Label("Creators", systemImage: "person.3.fill")
                }

            TrendingView()
                .tabItem {
                    Label("Trending", systemImage: "flame.fill")
                }

            ContentIdeasView()
                .tabItem {
                    Label("Ideas", systemImage: "lightbulb.fill")
                }

            DiscoveryView()
                .tabItem {
                    Label("Discover", systemImage: "magnifyingglass")
                }
        }
    }
}
