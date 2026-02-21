import SwiftUI

@main
struct InMarketingApp: App {
    @StateObject private var viewModel = ResearchViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}
