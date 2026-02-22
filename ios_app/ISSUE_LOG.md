# InMarketingApp — Issue Log

> Generated: 2026-02-22 | Auditor: Senior iOS Engineer
> **Severity Scale:** Critical > Major > Minor > Informational

---

## Summary

| Severity | Count | Category Breakdown |
|---|---|---|
| **Critical** | 5 | Memory safety (2), Concurrency (2), Data loss (1) |
| **Major** | 14 | Concurrency (3), Error handling (3), Memory (2), Interface resilience (3), Protocol (2), Architecture (1) |
| **Minor** | 9 | Interface (3), Code quality (3), Protocol (2), Performance (1) |
| **Informational** | 4 | Best practices, tooling |
| **Total** | **32** | |

---

## Critical Issues

### C-01: `Task.detached` captures `self` without `[weak self]` — retain cycle risk

**File:** `ResearchViewModel.swift:63-81`
**Category:** Memory Safety

```swift
currentTask = Task.detached { [sampleSize] in
    // ...
    await MainActor.run { [self] in    // ← explicit strong capture of self
        self.posts = samplePosts
        // ...
    }
}
```

**Problem:** The `Task` is stored in `currentTask` (a property of `self`), and the closure explicitly captures `[self]` strongly. This creates a reference cycle: `self → currentTask → closure → self`. The task will keep the ViewModel alive even if all views are dismissed. `Task.detached` does not automatically break this cycle on cancellation.

**Risk:** Memory leak of the entire ViewModel plus all loaded posts/creators data. On repeated "Load Sample Data" taps, leaked ViewModels accumulate.

---

### C-02: `generateAllReports()` runs heavy computation on Main Actor

**File:** `ResearchViewModel.swift:144-159`
**Category:** Concurrency / Main Thread Blocking

```swift
@MainActor
class ResearchViewModel: ObservableObject {
    func generateAllReports() {
        let generator = ReportGenerator(posts: posts, creators: creators, targetNiches: targetNiches)
        executiveSummary = generator.generateExecutiveSummary()
        creatorRankings = generator.generateCreatorRankings()
        // ... 4 more heavy computations
    }
}
```

**Problem:** The entire class is `@MainActor`, so `generateAllReports()` runs synchronously on the main thread. With 25 creators × 15 posts × 10 comments = 3,750 posts, this method:
1. Constructs 6 different analyzers (some via computed properties that re-create analyzers per access)
2. Iterates every post multiple times (engagement, trends, patterns, whitespace, quality)
3. Runs regex matching on every post text
4. Computes standard deviations across all engagement arrays

**Risk:** UI freeze of 500ms–2s+ depending on data size. With 100 creators (the max sample size), this could exceed iOS's watchdog threshold and cause a visible hang or even app termination.

---

### C-03: Report generation called synchronously during data load callback

**File:** `ResearchViewModel.swift:72-79`
**Category:** Concurrency / Main Thread Blocking

```swift
await MainActor.run { [self] in
    self.posts = samplePosts        // Triggers @Published, SwiftUI diffing
    self.creators = sampleCreators  // Triggers @Published, SwiftUI diffing
    self.hasData = true             // Triggers view transition animation
    self.isLoading = false
    self.rebuildAvailableNiches()   // Iterates all creators + posts
    self.generateAllReports()       // <-- ALL analysis runs here, on main thread
    Haptics.success()
}
```

**Problem:** After sample data generation returns to the main thread, we immediately: (a) set 4+ `@Published` properties (each triggering SwiftUI's view diffing), (b) rebuild niche list, (c) run all 6 report generators. This is a compounding main-thread bottleneck — the UI is frozen from the moment `MainActor.run` starts until `Haptics.success()` fires.

**Risk:** Same as C-02, but worse because view diffing cost compounds with analysis cost. The "loading" spinner will freeze before disappearing.

---

### C-04: `ReportGenerator` computed properties re-instantiate analyzers on every access

**File:** `ReportGenerator.swift:9-28`
**Category:** Concurrency / Wasteful Re-computation

```swift
private var engagementAnalyzer: EngagementAnalyzer {
    EngagementAnalyzer(posts: posts, creators: creators)
}
private var trendAnalyzer: TrendAnalyzer {
    var t = TrendAnalyzer(posts: posts)
    t.engagementAnalyzer = engagementAnalyzer  // creates ANOTHER EngagementAnalyzer
    return t
}
```

**Problem:** Every time `engagementAnalyzer` is accessed, a new struct is created. Within `generateExecutiveSummary()` alone, `engagementAnalyzer` is accessed at least 3 times (directly + via `trendAnalyzer` + via `qualityAnalyzer`), each creating a fresh copy. Across all 5 report methods, the `EngagementAnalyzer` may be constructed 10+ times per report cycle.

**Risk:** Multiplies the already-problematic main-thread compute time (C-02). Each analyzer copies the full `posts` and `creators` arrays.

---

### C-05: Imported data lost on app termination — no persistence

**File:** `ResearchViewModel.swift` (entire data lifecycle)
**Category:** Data Loss

**Problem:** All posts, creators, and generated reports are stored only in `@Published` memory properties. If the user imports a large CSV, generates reports, then force-quits or backgrounds the app long enough for iOS to reclaim memory, all data is lost. Only `favoritedCreatorIds` survives via UserDefaults.

**Risk:** Users who import real CSV data (the primary use case) lose their entire dataset and must re-import. This is the single biggest UX failure mode.

---

## Major Issues

### M-01: `DataLoader` is a mutable `class` with shared state

**File:** `DataLoader.swift:6-9`
**Category:** Memory Safety / Architecture

```swift
class DataLoader {
    var posts: [Post] = []
    var creators: [String: Creator] = [:]
    var loadErrors: [String] = []
}
```

**Problem:** `DataLoader` accumulates state across multiple import calls (via `loadPostsFromCSV`, `loadCreatorsCSV`, `loadFromJSON`). The `loadErrors` array is never cleared between calls, so errors from a first import leak into subsequent imports. The `posts` and `creators` arrays duplicate data already stored in the ViewModel.

**Risk:** (a) Stale error messages shown to users. (b) Double memory usage (data in both DataLoader and ViewModel). (c) Inconsistency if ViewModel clears data but DataLoader retains old state.

---

### M-02: `NSRegularExpression` compiled on every call — no caching

**Files:** `ContentPatternAnalyzer.swift:26`, `SentimentAnalyzer.swift:59`
**Category:** Performance / Memory

```swift
// Called once per post, per pattern (9 hooks × ~3 patterns = 27 regex compilations per post)
if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
```

**Problem:** `NSRegularExpression` compilation is expensive. With 375 posts and 27 patterns, that's 10,125 regex compilations per analysis run. The `try?` silently discards compilation errors.

**Risk:** Performance degradation at scale. Silent failure for invalid regex patterns.

---

### M-03: No cancellation support in `generateAllReports()`

**File:** `ResearchViewModel.swift:144-159`
**Category:** Concurrency

**Problem:** While `loadSampleData()` supports `Task.isCancelled` checks, `generateAllReports()` has no cancellation. If called during pull-to-refresh, tab changes, or niche search, multiple report generation cycles can overlap and pile up on the main thread.

**Risk:** Wasted CPU and UI stuttering when the user triggers rapid refreshes.

---

### M-04: `refreshNicheDiscovery()` runs on main thread with no debounce

**File:** `ResearchViewModel.swift:163-176`
**Category:** Concurrency

**Problem:** Called from `generateAllReports()` (already on main), from settings changes (`onChange` of ranking method and platform filter), and from niche search submit. Each call creates a `NicheDiscovery` struct and runs ranking + rising star algorithms synchronously.

**Risk:** UI freezes on settings changes and search submissions.

---

### M-05: CSV parsing doesn't handle edge cases

**File:** `DataLoader.swift:238-271`
**Category:** Error Handling

**Problem:** The CSV parser:
1. Doesn't handle escaped quotes (`""` inside quoted fields)
2. Doesn't handle fields starting with whitespace before a quote
3. `row.count >= headers.count` check silently skips rows with fewer columns instead of padding with empty strings
4. Treats any row that fails to parse as silent skip (no error logged)

**Risk:** Data loss on import with no feedback to the user.

---

### M-06: `loadErrors` never cleared between imports

**File:** `DataLoader.swift:9` / `ResearchViewModel.swift:113`
**Category:** Error Handling

```swift
// DataLoader
var loadErrors: [String] = []  // Never reset

// ViewModel reads them:
loadErrors = dataLoader.loadErrors
```

**Problem:** If a user imports Posts CSV (with warnings), then imports Creators CSV (clean), the error alert still shows the old Posts warnings.

**Risk:** Confusing error messages that don't match the most recent action.

---

### M-07: `loadJSON` uses unsafe `JSONSerialization` instead of `Codable`

**File:** `DataLoader.swift:65-95`
**Category:** Error Handling

```swift
guard let json = try? JSONSerialization.jsonObject(with: content) as? [String: Any] else {
    loadErrors.append("Invalid JSON format")
    return ([], [])
}
```

**Problem:** The models (`Post`, `Creator`) already conform to `Codable` with full `CodingKeys`, but JSON loading uses `JSONSerialization` + string casting instead. This means:
1. Nested objects (e.g., `metrics`) won't decode properly
2. Type coercion is lossy (`"\($0)"` turns arrays/dicts into debug descriptions)
3. The `Codable` conformance on all models is entirely unused

**Risk:** JSON import silently produces garbage data for nested fields.

---

### M-08: `exportToJSON()` bypasses `Codable` — schema mismatch

**File:** `DataLoader.swift:121-132`
**Category:** Error Handling

**Problem:** Manual `postToDict` / `creatorToDict` methods construct dictionaries that omit many fields present in the `Codable` models (e.g., `commentsList`, `hookType`, `contentFormat`, `growthHistory`, `engagementQualityScore`, etc.). Data exported then re-imported will lose information.

**Risk:** Round-trip data loss. Export → Import cycle silently drops fields.

---

### M-09: `AnimatedNumber` doesn't actually animate — incorrect `contentTransition` usage

**File:** `DesignSystem.swift:135-162`
**Category:** Interface Resilience

```swift
struct AnimatedNumber: View {
    @State private var displayValue: Double = 0

    var body: some View {
        Text(String(format: format, displayValue) + suffix)
            .onAppear {
                withAnimation(DS.Animation.standard) {
                    displayValue = value  // ← changes @State, but Text already shows final
                }
            }
            .contentTransition(.numericText(value: displayValue))
    }
}
```

**Problem:** `.contentTransition(.numericText(value:))` needs the `Text` content to change character-by-character for the transition to fire. But `displayValue` jumps from 0 to the final value in a single animation frame — there's no interpolation of the formatted string. The `withAnimation` wrapper animates the `@State` change, but `String(format:)` doesn't produce intermediate strings.

**Risk:** The component doesn't produce the intended number-counting animation. It just fades/slides.

---

### M-10: No Dynamic Type support — fixed font sizes

**File:** `DesignSystem.swift:30-41`
**Category:** Interface Resilience / Accessibility

```swift
enum Typo {
    static let heroValue: Font = .title2.bold()
    // ...all use system semantic sizes...
}
```

**Problem:** While the fonts use Apple's semantic sizes (good), several views use hardcoded frame widths that break with larger Dynamic Type:
- `CreatorRankingsView.swift:167` — `.frame(width: 28)` for rank number
- `TrendingView.swift:46` — `.frame(width: 28)` for rank
- `TrendingView.swift:92` — `.frame(width: 24)` for rank
- `TrendingView.swift:133,164` — `.frame(width: 100)` and `.frame(width: 60)` for labels
- `DashboardView.swift:93` — `.frame(width: 24)` for rank

**Risk:** At larger accessibility text sizes, numbers and labels will clip or overlap. Apple's accessibility audit would flag these.

---

### M-11: `StaggeredAppear` animation fires on every list re-render

**File:** `DesignSystem.swift:111-131`
**Category:** Interface Resilience

```swift
struct StaggeredAppear: ViewModifier {
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .onAppear {
                withAnimation(...) { appeared = true }
            }
    }
}
```

**Problem:** When a `List` or `ScrollView` recycles views (e.g., scrolling down then back up), `onAppear` fires again. The `@State appeared` is already `true` so no animation occurs — but the modifier still applies identity changes. More importantly, when the underlying data changes (e.g., pull-to-refresh), new view instances get `appeared = false` and the stagger animation replays, which feels janky on data refresh vs. initial load.

**Risk:** Visual jank on data refresh. Unnecessary view identity overhead.

---

### M-12: Missing `Sendable` conformance on model types

**Files:** `Models.swift` (all types)
**Category:** Concurrency / Swift 6 readiness

**Problem:** `Post`, `Creator`, `Comment`, etc. are `struct`s that conform to `Codable` and `Identifiable`, but not `Sendable`. They are passed across concurrency boundaries in `Task.detached` (line 63 of ViewModel). Under strict concurrency checking (Swift 6), this will produce errors.

**Risk:** Build failures when migrating to Swift 6 strict concurrency. Already produces warnings with `-strict-concurrency=complete`.

---

### M-13: `SampleDataGenerator` uses `Date()` for timestamps — non-deterministic tests

**File:** `SampleDataGenerator.swift:134,141,179`
**Category:** Architecture / Testability

**Problem:** Sample data timestamps are calculated relative to `Date()`, making output non-deterministic. This makes it impossible to write reproducible unit tests for trend analysis (which depends on "recent" vs "older" post dates).

**Risk:** Flaky tests, inability to assert specific trending/timing results.

---

### M-14: `formatNumber` is a free function — namespace pollution

**File:** `DesignSystem.swift:385-389`
**Category:** Protocol / Convention

```swift
func formatNumber(_ n: Int) -> String { ... }
```

**Problem:** Global free function in a SwiftUI framework. Should be namespaced (e.g., `DS.formatNumber()` or `Int.formatted(compact:)`).

**Risk:** Name collision. Discoverability issues. Not idiomatic Swift.

---

## Minor Issues

### m-01: `Combine` imported but never used directly

**File:** `ResearchViewModel.swift:3`, `CreatorRankingsView.swift:2`
**Category:** Code Quality

**Problem:** Both files `import Combine` but never use any Combine types directly. `@Published` is provided by the `Observation` framework (via `ObservableObject`), not `Combine` directly — though the underlying machinery uses it, the import is unnecessary at the usage level.

**Risk:** Unnecessary dependency declaration; confuses readers about whether Combine publishers are in use.

---

### m-02: `ContentTaxonomy` doesn't conform to `Codable`

**File:** `Models.swift:298-317`
**Category:** Protocol Conformance

**Problem:** `ContentTaxonomy` contains `[ContentHook]` and `[ContentFormat]` (which are `Codable`) but the struct itself lacks `Codable` conformance. This is the only core model type without it.

**Risk:** Cannot serialize/deserialize winning formulas if persistence is added later.

---

### m-03: Several report types use `let id = UUID()` — non-deterministic IDs

**Files:** `Models.swift` — `TrendingTopic`, `CreatorRankingItem`, `GrowthItem`, `HashtagItem`, `TrendItem`, `FormulaItem`, `WhitespaceItem`, `ContentIdea`, `CollaborationReportItem`, `TimingItem`, `TopicSaturation`
**Category:** Protocol / Testability

**Problem:** 11 report types generate a new `UUID()` as their `id` on each creation. This means:
1. The same logical data produces different IDs each run
2. SwiftUI's `ForEach` cannot maintain view identity across data refreshes
3. Equality comparisons for testing are unreliable

**Risk:** Unnecessary view reconstruction on refresh. Flaky test assertions.

---

### m-04: `Info.plist` declares document types but no `UTExportedTypeDeclarations`

**File:** `Info.plist`
**Category:** Interface Resilience

**Problem:** The plist declares the app can open CSV and JSON files but doesn't declare UTI exports or proper document handler registration. The `CFBundleDocumentTypes` may not work as expected without a full Xcode project.

**Risk:** "Open In" / file association may not work on-device.

---

### m-05: No `@ViewBuilder` optimization for conditional sections

**Files:** All view files
**Category:** Interface / Performance

**Problem:** Views like `DashboardView` use `if let summary = ...` at the top level of a `VStack`, which forces SwiftUI to maintain identity for the entire view tree conditional. Using `Group` or separate `@ViewBuilder` methods would give SwiftUI better diffing hints.

**Risk:** Minor performance impact on view updates.

---

### m-06: Hardcoded strings throughout — no localization

**Files:** All view files
**Category:** Interface Resilience

**Problem:** Every user-facing string is hardcoded English. No `.strings` files, no `LocalizedStringKey`, no `String(localized:)`.

**Risk:** Cannot localize the app without touching every view file.

---

### m-07: `CollaborationReportItem` duplicates `CollaborationTarget` fields

**File:** `Models.swift:367-386` and `Models.swift:488-500`
**Category:** Code Quality

**Problem:** `CollaborationTarget` and `CollaborationReportItem` contain nearly identical fields (`id`, `name/creatorName`, `platform`, `followers/followerCount`, `engagementRate`, `growthRate`, `nicheAlignmentScore`, `overallFitScore`). The report generator manually maps one to the other.

**Risk:** Maintenance burden. Changes to one must be mirrored in the other.

---

### m-08: `hashtagStats` dictionary accumulates posts arrays in memory

**File:** `TrendAnalyzer.swift:11-23`
**Category:** Performance

```swift
var hashtagStats: [String: (posts: [Post], totalEngagement: Int, ...)] = [:]
stats.posts.append(post)  // Each Post is a large struct (commentsList, text, etc.)
```

**Problem:** Each hashtag's stat entry holds a full array of `Post` objects. With many shared hashtags, the same Post object is duplicated across multiple hashtag buckets. Posts are value types, so each `append` copies the entire struct including its `commentsList` array.

**Risk:** O(n × h) memory where n = posts, h = avg hashtags per post. With 3,750 posts averaging 2 hashtags, this creates ~7,500 Post copies in memory during analysis.

---

### m-09: `TrendingView` best-times bar chart has no zero-baseline protection

**File:** `TrendingView.swift:136,167`
**Category:** Interface Resilience

```swift
let maxEng = report.bestPostingTimes.bestDays.map(\.avgEngagement).max() ?? 1
// ...
.frame(width: geo.size.width * (day.avgEngagement / maxEng))
```

**Problem:** If all engagement values are 0, `maxEng` becomes 1 (from the nil-coalescing), producing `0/1 = 0` width bars — which is correct but visually empty with no explanation. More importantly, if `maxEng` somehow becomes negative (edge case with bad data), the frame width goes negative.

**Risk:** Confusing empty chart with no "no data" explanation.

---

## Informational

### I-01: No test target in `Package.swift`

**File:** `Package.swift`

The SPM manifest has no `.testTarget`. There are no unit tests, UI tests, or snapshot tests anywhere in the project.

---

### I-02: No SwiftLint or formatting configuration

No `.swiftlint.yml`, no `.swift-format`, no Xcode build phase for linting.

---

### I-03: No SwiftUI `#Preview` macros

None of the view files contain `#Preview` macros (iOS 17+). This means no Xcode Canvas previews are available for rapid iteration.

---

### I-04: `Package.swift` declares macOS 14 target but code uses `UIKit` haptics

**File:** `DesignSystem.swift:83-95`

```swift
import UIKit  // implicit via SwiftUI on iOS
private static let impact = UIImpactFeedbackGenerator(style: .medium)
```

The `Package.swift` declares `.macOS(.v14)` as a platform, but `UIImpactFeedbackGenerator` is iOS-only. A macOS build would fail at compile time.

---

*End of issue log.*
