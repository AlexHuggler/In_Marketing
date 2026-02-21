import SwiftUI

struct TrendingView: View {
    @EnvironmentObject var viewModel: ResearchViewModel
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $selectedTab) {
                    Text("Trending").tag(0)
                    Text("Hashtags").tag(1)
                    Text("Best Times").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                ScrollView {
                    switch selectedTab {
                    case 0: trendingTopicsSection
                    case 1: hashtagsSection
                    case 2: bestTimesSection
                    default: EmptyView()
                    }
                }
            }
            .navigationTitle("Trends & Timing")
        }
    }

    // MARK: - Trending Topics

    private var trendingTopicsSection: some View {
        VStack(spacing: 12) {
            if let report = viewModel.trendingReport {
                ForEach(Array(report.trendingNow.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.topic)
                                .font(.headline)
                            Text("\(item.postCount) posts | \(Int(item.avgEngagement)) avg engagement")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            HStack(spacing: 2) {
                                Image(systemName: item.growthRate >= 0 ? "arrow.up.right" : "arrow.down.right")
                                Text(String(format: "%.0f%%", item.growthRate))
                            }
                            .font(.subheadline.bold())
                            .foregroundStyle(item.growthRate >= 0 ? .green : .red)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            } else {
                Text("No trending data available")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Hashtags

    private var hashtagsSection: some View {
        VStack(spacing: 12) {
            if let report = viewModel.trendingReport {
                ForEach(Array(report.topHashtags.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)

                        Text(item.hashtag)
                            .font(.headline)
                            .foregroundStyle(.blue)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "%.0f avg eng", item.avgEngagement))
                                .font(.subheadline.bold())
                            Text("\(item.postCount) posts")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding()
    }

    // MARK: - Best Times

    private var bestTimesSection: some View {
        VStack(spacing: 20) {
            if let report = viewModel.trendingReport {
                // Best Days
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Best Days to Post", icon: "calendar")

                    ForEach(report.bestPostingTimes.bestDays) { day in
                        HStack {
                            Text(day.label)
                                .font(.subheadline)
                                .frame(width: 100, alignment: .leading)

                            GeometryReader { geo in
                                let maxEng = report.bestPostingTimes.bestDays.map(\.avgEngagement).max() ?? 1
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemGray5))
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.blue)
                                        .frame(width: geo.size.width * (day.avgEngagement / maxEng))
                                }
                            }
                            .frame(height: 20)

                            Text(String(format: "%.0f", day.avgEngagement))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 50, alignment: .trailing)
                        }
                    }
                }
                .cardStyle()

                // Best Hours
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Best Hours to Post", icon: "clock.fill")

                    ForEach(report.bestPostingTimes.bestHours.prefix(10)) { hour in
                        HStack {
                            Text(hour.label)
                                .font(.subheadline)
                                .frame(width: 60, alignment: .leading)

                            GeometryReader { geo in
                                let maxEng = report.bestPostingTimes.bestHours.map(\.avgEngagement).max() ?? 1
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemGray5))
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.orange)
                                        .frame(width: geo.size.width * (hour.avgEngagement / maxEng))
                                }
                            }
                            .frame(height: 20)

                            Text(String(format: "%.0f", hour.avgEngagement))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 50, alignment: .trailing)
                        }
                    }
                }
                .cardStyle()
            }
        }
        .padding()
    }
}
