# In Marketing - iOS App

A native iOS (SwiftUI) port of the Influencer & Content Market Research Tool.

## Features

All functionality from the Python codebase has been recreated in Swift:

### Data Models
- **Post**: Social media posts with engagement metrics, hashtags, topics, velocity tracking
- **Creator**: Influencer profiles with follower counts, growth rates, niche classifications
- **EngagementMetrics**: Likes, comments, shares, saves, views with calculated rates
- **ContentTaxonomy**: Content pattern recognition for repeatable formulas

### Analytics Engine
- **EngagementAnalyzer**: Engagement rate, velocity, viral coefficient, save rate calculations
- **TrendAnalyzer**: Hashtag performance, topic trends, timing analysis
- **ContentPatternAnalyzer**: Hook detection, format classification, winning formula identification
- **WhitespaceAnalyzer**: Topic saturation analysis, underserved niche discovery
- **CollaborationAnalyzer**: Niche alignment scoring, collaboration target ranking
- **SentimentAnalyzer**: Comment quality, spam detection, engagement authenticity
- **NicheDiscovery**: Fuzzy niche matching, creator ranking, rising star detection

### Report Generation
- Executive Summary with key metrics and recommendations
- Creator Rankings by composite score (engagement + growth + authenticity + community)
- Content Ideas based on winning formulas and whitespace opportunities
- Collaboration Targets ranked by niche alignment
- Trending Topics and Hashtags with growth rates
- Best Posting Times by day and hour

### Data Import
- CSV file import (posts and creators)
- JSON file import
- Sample data generator for demonstration

## App Structure

```
InMarketingApp/
├── InMarketingApp.swift              # App entry point
├── Info.plist                        # iOS configuration
├── Models/
│   └── Models.swift                  # All data models and enums
├── Services/
│   ├── EngagementAnalyzer.swift      # Engagement rate & velocity analysis
│   ├── TrendAnalyzer.swift           # Trending topics & hashtag analysis
│   ├── ContentPatternAnalyzer.swift  # Content hook & format detection
│   ├── WhitespaceAnalyzer.swift      # Whitespace opportunity detection
│   ├── CollaborationAnalyzer.swift   # Collaboration target scoring
│   ├── SentimentAnalyzer.swift       # Comment quality & spam detection
│   ├── NicheDiscovery.swift          # Niche-based creator discovery
│   ├── ReportGenerator.swift         # Report generation engine
│   ├── DataLoader.swift              # CSV/JSON data import
│   └── SampleDataGenerator.swift     # Demo data generation
├── ViewModels/
│   └── ResearchViewModel.swift       # Main app state management
└── Views/
    ├── ContentView.swift             # Main tab view & welcome screen
    ├── DashboardView.swift           # Executive summary dashboard
    ├── CreatorRankingsView.swift      # Creator rankings & detail view
    ├── TrendingView.swift            # Trending topics, hashtags, timing
    ├── ContentIdeasView.swift        # Content formulas & collaboration
    └── DiscoveryView.swift           # Niche discovery & settings
```

## Setup in Xcode

1. Open Xcode
2. File > New > Project > iOS > App
3. Set Product Name to "InMarketingApp"
4. Set Interface to "SwiftUI", Language to "Swift"
5. Set minimum deployment target to iOS 17.0
6. Delete the auto-generated ContentView.swift
7. Drag all files from this `InMarketingApp/` folder into the Xcode project
8. Build and run (Cmd+R)

### Alternative: Swift Package Manager

```bash
cd ios_app
swift build
```

## Key Design Decisions

### Why SwiftUI?
- Declarative UI matches the data-driven nature of the tool
- Built-in support for reactive state management (@Published, @EnvironmentObject)
- Native iOS look and feel with minimal code

### Architecture
- **MVVM**: Single `ResearchViewModel` manages all state
- **Value Types**: Models are structs for thread safety and performance
- **Lazy Computation**: Reports generated on-demand, not eagerly

### Mapping from Python

| Python Module | Swift Equivalent |
|---|---|
| `models.py` | `Models/Models.swift` |
| `data_loader.py` | `Services/DataLoader.swift` |
| `analytics.py` | `Services/EngagementAnalyzer.swift`, `TrendAnalyzer.swift`, `ContentPatternAnalyzer.swift`, `WhitespaceAnalyzer.swift`, `CollaborationAnalyzer.swift` |
| `sentiment.py` | `Services/SentimentAnalyzer.swift` |
| `niche_discovery.py` | `Services/NicheDiscovery.swift` |
| `reporting.py` | `Services/ReportGenerator.swift` |
| `sample_data.py` | `Services/SampleDataGenerator.swift` |
| `run_research.py` | `ViewModels/ResearchViewModel.swift` + `Views/` |
| `find_top_creators.py` | `Views/DiscoveryView.swift` |

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+
