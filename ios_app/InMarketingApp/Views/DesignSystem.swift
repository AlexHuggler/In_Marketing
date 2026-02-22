import SwiftUI

// MARK: - Design Tokens

/// Centralized design system for consistent spacing, typography, and colors.
enum DS {

    // MARK: Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 32
    }

    // MARK: Corner Radius

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let pill: CGFloat = 100
    }

    // MARK: Typography (semantic)

    enum Typo {
        static let heroValue: Font = .title2.bold()
        static let sectionTitle: Font = .headline
        static let cardTitle: Font = .headline
        static let cardSubtitle: Font = .subheadline
        static let body: Font = .subheadline
        static let bodyBold: Font = .subheadline.bold()
        static let caption: Font = .caption
        static let captionBold: Font = .caption.bold()
        static let badge: Font = .caption2
        static let metric: Font = .title3.bold()
    }

    // MARK: Semantic Colors (dark-mode safe)

    enum Colors {
        static let accent = Color.blue
        static let success = Color.green
        static let warning = Color.orange
        static let danger = Color.red
        static let info = Color.purple

        static let cardBackground = Color(.systemBackground)
        static let surfaceBackground = Color(.systemGray6)
        static let secondaryText = Color(.secondaryLabel)
        static let tertiaryText = Color(.tertiaryLabel)

        static let engagementPink = Color.pink
        static let growthGreen = Color.green
        static let trendOrange = Color.orange
        static let nicheBlueTint = Color.blue.opacity(0.1)
    }

    // MARK: Shadows

    enum Shadow {
        static let card: (color: Color, radius: CGFloat, y: CGFloat) = (
            color: .black.opacity(0.06), radius: 6, y: 3
        )
    }

    // MARK: Animation

    enum Animation {
        static let quick: SwiftUI.Animation = .easeOut(duration: 0.2)
        static let standard: SwiftUI.Animation = .easeInOut(duration: 0.35)
        static let spring: SwiftUI.Animation = .spring(response: 0.4, dampingFraction: 0.75)
        static let staggerDelay: Double = 0.04
    }
}

// MARK: - Haptic Helpers

enum Haptics {
    private static let impact = UIImpactFeedbackGenerator(style: .medium)
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let notification = UINotificationFeedbackGenerator()
    private static let selection = UISelectionFeedbackGenerator()

    static func tap() { lightImpact.impactOccurred() }
    static func success() { notification.notificationOccurred(.success) }
    static func error() { notification.notificationOccurred(.error) }
    static func warning() { notification.notificationOccurred(.warning) }
    static func select() { selection.selectionChanged() }
    static func impact() { Self.impact.impactOccurred() }
}

// MARK: - Card Style Modifier (updated)

extension View {
    func cardStyle() -> some View {
        self
            .padding(DS.Spacing.lg)
            .background(DS.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .shadow(color: DS.Shadow.card.color, radius: DS.Shadow.card.radius, y: DS.Shadow.card.y)
    }
}

// MARK: - Staggered Appear Animation Modifier

struct StaggeredAppear: ViewModifier {
    let index: Int
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .onAppear {
                withAnimation(DS.Animation.standard.delay(Double(index) * DS.Animation.staggerDelay)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func staggeredAppear(index: Int) -> some View {
        modifier(StaggeredAppear(index: index))
    }
}

// MARK: - Animated Number Text

struct AnimatedNumber: View {
    let value: Double
    let format: String
    let suffix: String

    @State private var displayValue: Double = 0

    init(_ value: Double, format: String = "%.0f", suffix: String = "") {
        self.value = value
        self.format = format
        self.suffix = suffix
    }

    var body: some View {
        Text(String(format: format, displayValue) + suffix)
            .onAppear {
                withAnimation(DS.Animation.standard) {
                    displayValue = value
                }
            }
            .onChange(of: value) { _, newValue in
                withAnimation(DS.Animation.standard) {
                    displayValue = newValue
                }
            }
            .contentTransition(.numericText(value: displayValue))
    }
}

// MARK: - Reusable Components (updated)

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(DS.Colors.accent)
            Text(title)
                .font(DS.Typo.sectionTitle)
        }
        .accessibilityElement(children: .combine)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(DS.Typo.heroValue)
                .contentTransition(.numericText())
            Text(title)
                .font(DS.Typo.caption)
                .foregroundStyle(DS.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(DS.Colors.surfaceBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

struct PriorityBadge: View {
    let priority: String

    var color: Color {
        switch priority {
        case "High": return DS.Colors.danger
        case "Medium": return DS.Colors.warning
        default: return DS.Colors.success
        }
    }

    var body: some View {
        Text(priority)
            .font(DS.Typo.captionBold)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct StatPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(DS.Typo.sectionTitle)
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .font(DS.Typo.badge)
                .foregroundStyle(DS.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.sm)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

struct MetricTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            Text(value)
                .font(DS.Typo.sectionTitle)
                .contentTransition(.numericText())
            Text(title)
                .font(DS.Typo.caption)
                .foregroundStyle(DS.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.lg)
        .background(DS.Colors.surfaceBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm + 2))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

struct ScoreBar: View {
    let label: String
    let score: Double
    @State private var animatedScore: Double = 0

    var color: Color {
        if animatedScore >= 70 { return DS.Colors.success }
        if animatedScore >= 40 { return DS.Colors.warning }
        return DS.Colors.danger
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack {
                Text(label)
                    .font(DS.Typo.body)
                Spacer()
                Text(String(format: "%.0f", animatedScore))
                    .font(DS.Typo.bodyBold)
                    .foregroundStyle(color)
                    .contentTransition(.numericText(value: animatedScore))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DS.Colors.surfaceBackground)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * min(animatedScore / 100.0, 1.0))
                }
            }
            .frame(height: 8)
        }
        .onAppear {
            withAnimation(DS.Animation.standard.delay(0.15)) {
                animatedScore = score
            }
        }
    }
}

struct MiniScore: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(String(format: "%.0f", value))
                .font(DS.Typo.captionBold)
                .foregroundStyle(color)
                .contentTransition(.numericText(value: value))
            Text(label)
                .font(DS.Typo.badge)
                .foregroundStyle(DS.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(String(format: "%.0f", value))")
    }
}

struct FlowLayout<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: DS.Spacing.sm) {
            ForEach(items, id: \.self) { item in
                content(item)
            }
        }
    }
}

// MARK: - Empty State (reusable)

struct EmptyStateView: View {
    let icon: String
    let message: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(DS.Colors.tertiaryText)
                .symbolEffect(.pulse, options: .repeating)
            Text(message)
                .font(DS.Typo.body)
                .foregroundStyle(DS.Colors.secondaryText)
                .multilineTextAlignment(.center)
            if let actionLabel, let action {
                Button(action: action) {
                    Text(actionLabel)
                        .font(DS.Typo.bodyBold)
                        .foregroundStyle(DS.Colors.accent)
                }
                .padding(.top, DS.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Formatting Helpers

func formatNumber(_ n: Int) -> String {
    if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
    if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
    return "\(n)"
}
