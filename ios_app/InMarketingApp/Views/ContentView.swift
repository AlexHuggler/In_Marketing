import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: ResearchViewModel

    var body: some View {
        Group {
            if viewModel.hasData {
                MainTabView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                WelcomeView()
            }
        }
        .animation(DS.Animation.standard, value: viewModel.hasData)
        .alert("Import Notice", isPresented: $viewModel.showErrorAlert) {
            Button("OK") { viewModel.showErrorAlert = false }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}

// MARK: - Welcome / Onboarding

struct WelcomeView: View {
    @EnvironmentObject var viewModel: ResearchViewModel
    @State private var showFileImporter = false
    @State private var importType = ""
    @State private var iconBounce = false

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.xxl) {
                Spacer()

                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(DS.Colors.accent)
                    .symbolEffect(.bounce, value: iconBounce)
                    .onAppear { iconBounce.toggle() }

                VStack(spacing: DS.Spacing.sm) {
                    Text("Influencer Research")
                        .font(.largeTitle.bold())
                    Text("Content Market Research Tool")
                        .font(.title3)
                        .foregroundStyle(DS.Colors.secondaryText)
                }

                Text("Track engagement metrics, discover trending topics, find top voices by niche, and identify content patterns for actionable marketing decisions.")
                    .font(DS.Typo.body)
                    .foregroundStyle(DS.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()

                VStack(spacing: DS.Spacing.lg) {
                    Button {
                        Haptics.tap()
                        viewModel.loadSampleData()
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Load Sample Data")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(DS.Spacing.lg)
                        .background(DS.Colors.accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    }
                    .disabled(viewModel.isLoading)

                    Button {
                        Haptics.select()
                        importType = "posts"
                        showFileImporter = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                            Text("Import Posts CSV")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(DS.Spacing.lg)
                        .background(DS.Colors.surfaceBackground)
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    }

                    Button {
                        Haptics.select()
                        importType = "creators"
                        showFileImporter = true
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Import Creators CSV")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(DS.Spacing.lg)
                        .background(DS.Colors.surfaceBackground)
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    }
                }
                .padding(.horizontal)

                if viewModel.isLoading {
                    VStack(spacing: DS.Spacing.sm) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Generating \(viewModel.sampleSize) creators with posts...")
                            .font(DS.Typo.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                    }
                    .padding()
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
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
        case .failure(let error):
            viewModel.errorMessage = "File import failed: \(error.localizedDescription)"
            viewModel.showErrorAlert = true
            Haptics.error()
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
                .tag(0)

            CreatorRankingsView()
                .tabItem { Label("Creators", systemImage: "person.3.fill") }
                .tag(1)

            TrendingView()
                .tabItem { Label("Trending", systemImage: "flame.fill") }
                .tag(2)

            ContentIdeasView()
                .tabItem { Label("Ideas", systemImage: "lightbulb.fill") }
                .tag(3)

            DiscoveryView()
                .tabItem { Label("Discover", systemImage: "magnifyingglass") }
                .tag(4)
        }
        .onChange(of: selectedTab) { _, _ in
            Haptics.select()
        }
    }
}
