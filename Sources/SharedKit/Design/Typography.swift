import SwiftUI

/// Centralized typography system for consistent text styling
/// All styles support Dynamic Type for accessibility
public enum Typography {
    // MARK: - Heading Styles

    // Uses semantic text styles that automatically scale with Dynamic Type

    /// Heading 1 (title, bold) - maps to ~28pt at default size
    public static let h1 = Font.title.weight(.bold)

    /// Heading 2 (title2, semibold) - maps to ~22pt at default size
    public static let h2 = Font.title2.weight(.semibold)

    /// Heading 3 (title3, semibold) - maps to ~20pt at default size
    public static let h3 = Font.title3.weight(.semibold)

    /// Heading 4 (headline, semibold) - maps to ~17pt at default size
    public static let h4 = Font.headline.weight(.semibold)

    // MARK: - Body Styles

    /// Large body text (body, regular) - standard reading text (~17pt at default)
    public static let bodyLarge = Font.body.weight(.regular)

    /// Medium body text (callout, regular) - default body text (~16pt at default)
    public static let bodyMedium = Font.callout.weight(.regular)

    /// Small body text (subheadline, regular) - secondary content (~15pt at default)
    public static let bodySmall = Font.subheadline.weight(.regular)

    // MARK: - Label Styles

    /// Large label (subheadline, medium) - for prominent labels (~15pt at default)
    public static let labelLarge = Font.subheadline.weight(.medium)

    /// Medium label (callout, medium) - for standard labels (~16pt at default)
    public static let labelMedium = Font.callout.weight(.medium)

    /// Small label (footnote, medium) - for compact labels (~13pt at default)
    public static let labelSmall = Font.footnote.weight(.medium)

    // MARK: - Caption Styles

    /// Large caption (footnote, regular) - for secondary information (~13pt at default)
    public static let captionLarge = Font.footnote.weight(.regular)

    /// Medium caption (caption, regular) - for timestamps, metadata (~12pt at default)
    public static let captionMedium = Font.caption.weight(.regular)

    /// Small caption (caption2, regular) - for fine print (~11pt at default)
    public static let captionSmall = Font.caption2.weight(.regular)

    // MARK: - Special Styles

    /// Stat value (title, bold) - for dashboard stats
    public static let statValue = Font.title.weight(.bold)

    /// Button text (headline) - for buttons
    public static let button = Font.headline
}

// MARK: - Scaled Display Font Modifiers

private struct ScaledDisplayLargeFont: ViewModifier {
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 48
    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: .bold, design: .rounded))
    }
}

private struct ScaledDisplayMediumFont: ViewModifier {
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 42
    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: .bold))
    }
}

private struct ScaledDisplaySmallFont: ViewModifier {
    @ScaledMetric(relativeTo: .title) private var size: CGFloat = 36
    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: .bold))
    }
}

private struct ScaledScoreDisplayFont: ViewModifier {
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 72
    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: .bold, design: .rounded))
    }
}

// MARK: - Themed Text Style

/// Applies a font and a theme-driven foreground color, reading `\.appTheme` at render time
/// so per-app overrides (e.g. SplitScreenTheme's slate-900 textPrimary) flow through `.h1()`
/// / `.body()` / etc. instead of binding to `ColorPalette` at modifier-construction time.
/// When `colorOverride` is non-nil, it wins; otherwise the modifier reads the supplied
/// `KeyPath` from the env theme's `colors`. With no theme injected the env defaults to
/// `DefaultTheme()`, whose `textPrimary` is `Color.primary` and `textSecondary` is
/// `Color.secondary`, preserving prior behavior for consumers that don't inject a theme.
private struct ThemedTextStyle: ViewModifier {
    @Environment(\.appTheme) private var theme
    let font: Font
    let colorOverride: Color?
    let defaultColor: KeyPath<ColorTokens, Color>

    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundColor(colorOverride ?? theme.colors[keyPath: defaultColor])
    }
}

// MARK: - View Extensions for Typography

public extension View {
    /// Apply typography style with semantic color.
    /// - Parameters:
    ///   - typography: The typography style to apply
    ///   - color: Optional explicit color override; when nil, reads `theme.colors.textPrimary`
    ///            from the `\.appTheme` environment.
    func style(
        _ typography: Font,
        color: Color? = nil
    ) -> some View {
        modifier(ThemedTextStyle(
            font: typography,
            colorOverride: color,
            defaultColor: \.textPrimary
        ))
    }

    func displayLargeFont() -> some View {
        modifier(ScaledDisplayLargeFont())
    }

    func displayMediumFont() -> some View {
        modifier(ScaledDisplayMediumFont())
    }

    func displaySmallFont() -> some View {
        modifier(ScaledDisplaySmallFont())
    }

    func scoreDisplayFont() -> some View {
        modifier(ScaledScoreDisplayFont())
    }
}

// MARK: - Text Extensions

public extension Text {
    /// Create text with heading 1 style. Reads `theme.colors.textPrimary` from
    /// `\.appTheme` when no explicit color is supplied.
    func h1(_ color: Color? = nil) -> some View {
        modifier(ThemedTextStyle(
            font: Typography.h1,
            colorOverride: color,
            defaultColor: \.textPrimary
        ))
    }

    /// Create text with heading 2 style. Reads `theme.colors.textPrimary` from
    /// `\.appTheme` when no explicit color is supplied.
    func h2(_ color: Color? = nil) -> some View {
        modifier(ThemedTextStyle(
            font: Typography.h2,
            colorOverride: color,
            defaultColor: \.textPrimary
        ))
    }

    /// Create text with heading 3 style. Reads `theme.colors.textPrimary` from
    /// `\.appTheme` when no explicit color is supplied.
    func h3(_ color: Color? = nil) -> some View {
        modifier(ThemedTextStyle(
            font: Typography.h3,
            colorOverride: color,
            defaultColor: \.textPrimary
        ))
    }

    /// Create text with body style. Reads `theme.colors.textPrimary` from
    /// `\.appTheme` when no explicit color is supplied.
    func body(_ color: Color? = nil) -> some View {
        modifier(ThemedTextStyle(
            font: Typography.bodyMedium,
            colorOverride: color,
            defaultColor: \.textPrimary
        ))
    }

    /// Create text with caption style. Reads `theme.colors.textSecondary` from
    /// `\.appTheme` when no explicit color is supplied.
    func caption(_ color: Color? = nil) -> some View {
        modifier(ThemedTextStyle(
            font: Typography.captionMedium,
            colorOverride: color,
            defaultColor: \.textSecondary
        ))
    }
}
