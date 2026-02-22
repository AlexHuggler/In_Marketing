# InMarketingApp — Project Map

> Generated: 2026-02-22 | Source: `ios_app/` directory
> **Purpose:** High-level architectural audit — no change proposals.

---

## 1. Primary Frameworks

| Layer | Framework | Version Constraint |
|---|---|---|
| UI | **SwiftUI** | iOS 17+ (uses `NavigationStack`, `symbolEffect`, `.contentTransition`) |
| Reactivity | **Combine** (imported but unused directly — `@Published` only) | — |
| Platform Kit | **UIKit** (haptics only: `UIImpactFeedbackGenerator`, etc.) | — |
| Foundation | **Foundation** (`NSRegularExpression`, `DateFormatter`, `JSONSerialization`, `UserDefaults`) | — |
| Type Identifiers | **UniformTypeIdentifiers** (file import content types) | — |

**No third-party dependencies.** No SPM packages, CocoaPods, or Carthage.

---

## 2. Dependency Management

| Mechanism | File | Notes |
|---|---|---|
| Swift Package Manager | `Package.swift` | Declares `executableTarget` for `InMarketingApp`. Targets iOS 17 / macOS 14. Zero external dependencies. |
| Xcode Project | *(not present)* | README instructs users to create an Xcode project manually. No `.xcodeproj` or `.xcworkspace`. |

---

## 3. Pattern Strategy

### Architecture: MVVM (Single ViewModel)

```
┌─────────────────────────────────────────────┐
│                    App Entry                 │
│          InMarketingApp.swift (@main)        │
│  @StateObject viewModel = ResearchViewModel  │
└─────────────────┬───────────────────────────┘
                  │ .environmentObject(viewModel)
                  ▼
┌─────────────────────────────────────────────┐
│                 ContentView                  │
│   Routes to WelcomeView or MainTabView      │
└─────────────────┬───────────────────────────┘
                  │
    ┌─────────────┼─────────────┐
    ▼             ▼             ▼
┌────────┐ ┌──────────┐ ┌───────────┐
│Dashboard│ │ Creators │ │ Trending  │  ...2 more tabs
│  View   │ │ Rankings │ │   View    │
└────┬───┘ └────┬─────┘ └────┬──────┘
     │          │             │
     ▼          ▼             ▼
┌─────────────────────────────────────────────┐
│          ResearchViewModel (@MainActor)       │
│  @Published posts, creators, reports, ...    │
│  Orchestrates all service calls               │
└─────────────────┬───────────────────────────┘
                  │ creates on each call
                  ▼
┌─────────────────────────────────────────────┐
│              Service Layer (structs)          │
│  EngagementAnalyzer   TrendAnalyzer          │
│  ContentPatternAnalyzer  WhitespaceAnalyzer  │
│  CollaborationAnalyzer  SentimentAnalyzer    │
│  NicheDiscovery  ReportGenerator             │
│  SampleDataGenerator  DataLoader (class)     │
└─────────────────────────────────────────────┘
                  │ operates on
                  ▼
┌─────────────────────────────────────────────┐
│              Model Layer (structs)            │
│  Post  Creator  EngagementMetrics  Comment   │
│  + 15 report/item types                      │
└─────────────────────────────────────────────┘
```

### Key Patterns Observed

| Pattern | Where | Description |
|---|---|---|
| **MVVM** | ViewModel → Views | Single `ResearchViewModel` drives all 6 view trees via `@EnvironmentObject` |
| **Stateless Services** | Services/ | 9 of 10 services are value-type `struct`s created fresh per analysis run |
| **Stateful Singleton** | `DataLoader` | Only `class` in services — holds mutable `posts`, `creators`, `loadErrors` |
| **Design System Tokens** | `DesignSystem.swift` | Centralized `DS` enum for spacing, colors, typography, radius, shadows, animations |
| **Haptic Feedback** | `Haptics` enum | Every user interaction fires haptic via `UIKit` generators |
| **Computed Analyzer Properties** | `ReportGenerator` | Lazily constructs analyzers via computed `var`s (re-created per access) |

---

## 4. Persistence Layer

| Mechanism | Scope | Data | Location |
|---|---|---|---|
| **UserDefaults** | Favorites | `Set<String>` of creator IDs | Key: `com.inmarketing.favoriteCreatorIds` |
| **In-Memory** | All data | Posts, Creators, Reports, Rankings | Held as `@Published` vars on `ResearchViewModel` |
| **No CoreData/SwiftData** | — | — | — |
| **No Keychain** | — | — | — |
| **No File System Cache** | — | Imported data is not persisted to disk | — |

**Implication:** All imported/generated data is lost on app termination. Only favorites survive restart.

---

## 5. Networking Stack

**None.** The app is fully offline/local:

- Data enters via file import (CSV/JSON via `.fileImporter`) or sample data generation.
- No `URLSession`, no REST API, no GraphQL, no WebSocket.
- No authentication, no API keys, no remote config.

---

## 6. Entry Point

```
ios_app/InMarketingApp/InMarketingApp.swift
```

```swift
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
```

**Lifecycle:** `@StateObject` creates the ViewModel once. It is injected into the entire view hierarchy via `.environmentObject()`. `ContentView` conditionally routes to `WelcomeView` (onboarding/import) or `MainTabView` (5-tab workspace) based on `viewModel.hasData`.

---

## 7. Module Dependency Map

### File-Level Dependencies (→ means "imports/uses")

```
InMarketingApp.swift
  → ResearchViewModel
  → ContentView

ContentView.swift
  → WelcomeView, MainTabView
  → ResearchViewModel (via @EnvironmentObject)
  → DataLoader (via ViewModel)
  → Haptics, DS

MainTabView (in ContentView.swift)
  → DashboardView
  → CreatorRankingsView
  → TrendingView
  → ContentIdeasView
  → DiscoveryView

ResearchViewModel.swift
  → SampleDataGenerator
  → DataLoader
  → ReportGenerator
  → WhitespaceAnalyzer
  → NicheDiscovery
  → Haptics
  → All Model types

ReportGenerator.swift
  → EngagementAnalyzer
  → TrendAnalyzer
  → ContentPatternAnalyzer
  → WhitespaceAnalyzer
  → CollaborationAnalyzer
  → EngagementQualityAnalyzer (in SentimentAnalyzer.swift)
  → All Report Model types

EngagementAnalyzer.swift
  → Models (Post, Creator)
  → Array<Double>.mean, .standardDeviation (self-defined extensions)

TrendAnalyzer.swift
  → Models (Post, HashtagItem, TrendingTopic, TimingAnalysis)
  → EngagementAnalyzer (optional reference)
  → Array<Double>.mean (from EngagementAnalyzer.swift)

ContentPatternAnalyzer.swift
  → Models (Post, ContentTaxonomy, ContentHook, ContentFormat)
  → NSRegularExpression

SentimentAnalyzer.swift
  → Models (Post, Comment)
  → NSRegularExpression
  → Array<Double>.mean (from EngagementAnalyzer.swift)

WhitespaceAnalyzer.swift
  → Models (Post, Creator, WhitespaceOpportunity)
  → Array<Double>.mean (from EngagementAnalyzer.swift)

CollaborationAnalyzer.swift
  → Models (Creator, CollaborationTarget)

NicheDiscovery.swift
  → Models (Creator, Post, SocialPlatform)
  → Array<Double>.mean, .standardDeviation (from EngagementAnalyzer.swift)

DataLoader.swift
  → Models (Post, Creator, SocialPlatform, MediaType)
  → UniformTypeIdentifiers
  → JSONSerialization

SampleDataGenerator.swift
  → Models (Post, Creator, Comment, EngagementMetrics, SocialPlatform, MediaType)

DesignSystem.swift
  → SwiftUI
  → UIKit (UIImpactFeedbackGenerator, etc.)
```

### Implicit Cross-File Dependency: `Array<Double>` Extensions

The `mean` and `standardDeviation` extensions on `Array where Element == Double` are **defined in `EngagementAnalyzer.swift`** but **used across 5 files**:

| File | Uses `.mean` | Uses `.standardDeviation` |
|---|---|---|
| EngagementAnalyzer.swift | Yes | Yes |
| TrendAnalyzer.swift | Yes | No |
| NicheDiscovery.swift | Yes | Yes |
| WhitespaceAnalyzer.swift | Yes | No |
| SentimentAnalyzer.swift | Yes | No |
| ReportGenerator.swift (via EngagementAnalyzer) | Yes | Yes |

---

## 8. Complete File Inventory

### Root (`ios_app/`)

| File | Lines | Role |
|---|---|---|
| `Package.swift` | 20 | SPM manifest |
| `README.md` | — | Setup documentation |
| `project_map.md` | — | This file |

### App (`InMarketingApp/`)

| File | Lines | Role |
|---|---|---|
| `InMarketingApp.swift` | 13 | `@main` entry point |
| `Info.plist` | ~50 | Bundle config, document type declarations |

### Models (`Models/`)

| File | Lines | Role |
|---|---|---|
| `Models.swift` | 513 | All data models: 4 enums, 5 core structs, 15 report types |

### Services (`Services/`)

| File | Lines | Type | Role |
|---|---|---|---|
| `EngagementAnalyzer.swift` | 201 | struct | Engagement rate, velocity, viral coefficient, creator metrics |
| `TrendAnalyzer.swift` | 181 | struct | Hashtag/topic performance, trending detection, timing analysis |
| `ContentPatternAnalyzer.swift` | 213 | struct | Hook detection (regex), format classification, winning formulas |
| `WhitespaceAnalyzer.swift` | 127 | struct | Topic saturation, whitespace opportunities, underserved niches |
| `CollaborationAnalyzer.swift` | 69 | struct | Niche alignment scoring, collaboration potential |
| `SentimentAnalyzer.swift` | 221 | struct | Comment sentiment, spam detection, engagement authenticity |
| `NicheDiscovery.swift` | 345 | struct | Fuzzy niche matching, creator ranking, rising stars |
| `ReportGenerator.swift` | 255 | struct | Orchestrates all analyzers into unified reports |
| `SampleDataGenerator.swift` | 227 | struct | Generates realistic demo data |
| `DataLoader.swift` | 301 | **class** | CSV/JSON parsing, flexible column mapping, export |

### ViewModels (`ViewModels/`)

| File | Lines | Role |
|---|---|---|
| `ResearchViewModel.swift` | 263 | `@MainActor ObservableObject` — single source of truth |

### Views (`Views/`)

| File | Lines | Role |
|---|---|---|
| `DesignSystem.swift` | 389 | DS tokens, Haptics, reusable components, modifiers |
| `ContentView.swift` | 187 | Root view, WelcomeView, MainTabView routing |
| `DashboardView.swift` | 262 | Executive summary dashboard (8 card sections) |
| `CreatorRankingsView.swift` | 363 | Searchable creator list with detail view |
| `TrendingView.swift` | 192 | Trending topics, hashtags, best posting times |
| `ContentIdeasView.swift` | 269 | Content formulas, whitespace, collaboration targets |
| `DiscoveryView.swift` | 490 | Niche search with autocomplete, settings sheet |

---

## 9. Data Flow Summary

```
User Action
    │
    ├─ "Load Sample Data" ──→ SampleDataGenerator.generateSampleData()
    │                              │
    ├─ "Import CSV/JSON"  ──→ DataLoader.loadPostsFromCSV() / loadFromJSON()
    │                              │
    ▼                              ▼
ResearchViewModel
    │  stores in @Published posts, creators
    │
    ├──→ generateAllReports()
    │       ├──→ ReportGenerator.generateExecutiveSummary()
    │       │       ├──→ EngagementAnalyzer
    │       │       ├──→ TrendAnalyzer
    │       │       ├──→ ContentPatternAnalyzer
    │       │       └──→ WhitespaceAnalyzer
    │       ├──→ ReportGenerator.generateCreatorRankings()
    │       │       ├──→ EngagementAnalyzer
    │       │       └──→ EngagementQualityAnalyzer (SentimentAnalyzer)
    │       ├──→ ReportGenerator.generateContentIdeas()
    │       ├──→ ReportGenerator.generateCollaborationTargets()
    │       ├──→ ReportGenerator.generateTrendingReport()
    │       └──→ WhitespaceAnalyzer.identifyWhitespaceOpportunities()
    │
    └──→ refreshNicheDiscovery()
            ├──→ NicheDiscovery.rankCreatorsInNiche()
            └──→ NicheDiscovery.findRisingStars()
```

---

## 10. Build Configuration

| Setting | Value |
|---|---|
| Swift Tools Version | 5.9 |
| Minimum iOS | 17.0 |
| Minimum macOS | 14.0 |
| Target Type | `executableTarget` (SPM) |
| Build System | SPM only (no `.xcodeproj`) |
| Test Target | **None** |
| CI/CD | **None** |
| Linting | **None** (no SwiftLint config) |
| Code Signing | **Not configured** (no Xcode project) |

---

*End of project map. No changes proposed.*
