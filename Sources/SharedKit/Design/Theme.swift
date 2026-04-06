import SwiftUI

// MARK: - Color Tokens

/// Semantic color tokens available for theming
public struct ColorTokens {
    // Brand
    /// Primary brand color
    public let primary: Color
    /// Secondary brand color
    public let secondary: Color

    // Semantic (icon use; low contrast in light mode — use accessible text variants for text)
    /// Success color — use for icons only, not text (low contrast in light mode)
    public let success: Color
    /// Warning color — use for icons only, not text (low contrast in light mode)
    public let warning: Color
    /// Error color — large text only in light mode (>= 18pt)
    public let error: Color
    /// Info color — large text only in light mode (>= 18pt)
    public let info: Color

    // Accessible text variants (WCAG AA compliant; use for text, not icons)
    /// Accessible success text color (WCAG AA 4.5:1)
    public let successText: Color
    /// Accessible warning text color (WCAG AA 4.5:1)
    public let warningText: Color
    /// Accessible error text color (WCAG AA 4.5:1)
    public let errorText: Color
    /// Accessible info text color (WCAG AA 4.5:1)
    public let infoText: Color

    // Text
    /// Primary text color
    public let textPrimary: Color
    /// Secondary text color (lighter)
    public let textSecondary: Color
    /// Tertiary text color (lightest)
    public let textTertiary: Color

    // Background
    /// Primary background color
    public let background: Color
    /// Secondary background color (cards, elevated surfaces)
    public let backgroundSecondary: Color
    /// Tertiary background color (nested content)
    public let backgroundTertiary: Color
    /// Grouped background color (lists, table views)
    public let backgroundGrouped: Color

    // Stat card colors
    /// Stat card color for "Tests Taken" style metrics
    public let statBlue: Color
    /// Stat card color for "Average" style metrics
    public let statGreen: Color
    /// Stat card color for time/duration stats
    public let statPurple: Color
    /// Stat card color for "Best Score" style metrics
    public let statOrange: Color

    // Surface text
    /// Text color for content on filled/colored backgrounds (buttons, banners)
    public let textOnPrimary: Color

    // Overlay
    /// Semi-transparent scrim for modal backdrops
    public let scrim: Color

    public init(
        primary: Color,
        secondary: Color,
        success: Color,
        warning: Color,
        error: Color,
        info: Color,
        successText: Color,
        warningText: Color,
        errorText: Color,
        infoText: Color,
        textPrimary: Color,
        textSecondary: Color,
        textTertiary: Color,
        background: Color,
        backgroundSecondary: Color,
        backgroundTertiary: Color,
        backgroundGrouped: Color,
        statBlue: Color,
        statGreen: Color,
        statPurple: Color,
        statOrange: Color,
        textOnPrimary: Color = ColorPalette.textOnPrimary,
        scrim: Color = ColorPalette.scrim
    ) {
        self.primary = primary
        self.secondary = secondary
        self.success = success
        self.warning = warning
        self.error = error
        self.info = info
        self.successText = successText
        self.warningText = warningText
        self.errorText = errorText
        self.infoText = infoText
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.textTertiary = textTertiary
        self.background = background
        self.backgroundSecondary = backgroundSecondary
        self.backgroundTertiary = backgroundTertiary
        self.backgroundGrouped = backgroundGrouped
        self.statBlue = statBlue
        self.statGreen = statGreen
        self.statPurple = statPurple
        self.statOrange = statOrange
        self.textOnPrimary = textOnPrimary
        self.scrim = scrim
    }
}

// MARK: - Typography Tokens

/// Typography tokens mirroring the Typography enum
public struct TypographyTokens {
    public let h1: Font
    public let h2: Font
    public let h3: Font
    public let h4: Font
    public let bodyLarge: Font
    public let bodyMedium: Font
    public let bodySmall: Font
    public let labelLarge: Font
    public let labelMedium: Font
    public let labelSmall: Font
    public let captionLarge: Font
    public let captionMedium: Font
    public let captionSmall: Font
    public let statValue: Font
    public let button: Font

    public init(
        h1: Font,
        h2: Font,
        h3: Font,
        h4: Font,
        bodyLarge: Font,
        bodyMedium: Font,
        bodySmall: Font,
        labelLarge: Font,
        labelMedium: Font,
        labelSmall: Font,
        captionLarge: Font,
        captionMedium: Font,
        captionSmall: Font,
        statValue: Font,
        button: Font
    ) {
        self.h1 = h1
        self.h2 = h2
        self.h3 = h3
        self.h4 = h4
        self.bodyLarge = bodyLarge
        self.bodyMedium = bodyMedium
        self.bodySmall = bodySmall
        self.labelLarge = labelLarge
        self.labelMedium = labelMedium
        self.labelSmall = labelSmall
        self.captionLarge = captionLarge
        self.captionMedium = captionMedium
        self.captionSmall = captionSmall
        self.statValue = statValue
        self.button = button
    }
}

// MARK: - Spacing Tokens

/// Spacing tokens mirroring DesignSystem.Spacing
public struct SpacingTokens {
    public let xs: CGFloat
    public let sm: CGFloat
    public let md: CGFloat
    public let lg: CGFloat
    public let xl: CGFloat
    public let xxl: CGFloat
    public let xxxl: CGFloat
    public let huge: CGFloat
    public let section: CGFloat

    public init(
        xs: CGFloat,
        sm: CGFloat,
        md: CGFloat,
        lg: CGFloat,
        xl: CGFloat,
        xxl: CGFloat,
        xxxl: CGFloat,
        huge: CGFloat,
        section: CGFloat
    ) {
        self.xs = xs
        self.sm = sm
        self.md = md
        self.lg = lg
        self.xl = xl
        self.xxl = xxl
        self.xxxl = xxxl
        self.huge = huge
        self.section = section
    }
}

// MARK: - Corner Radius Tokens

/// Corner radius tokens mirroring DesignSystem.CornerRadius
public struct CornerRadiusTokens {
    public let sm: CGFloat
    public let md: CGFloat
    public let lg: CGFloat
    public let xl: CGFloat
    public let full: CGFloat

    public init(sm: CGFloat, md: CGFloat, lg: CGFloat, xl: CGFloat, full: CGFloat) {
        self.sm = sm
        self.md = md
        self.lg = lg
        self.xl = xl
        self.full = full
    }
}

// MARK: - Shadow Tokens

/// Shadow tokens mirroring DesignSystem.Shadow
public struct ShadowTokens {
    public let sm: ShadowStyle
    public let md: ShadowStyle
    public let lg: ShadowStyle

    public init(sm: ShadowStyle, md: ShadowStyle, lg: ShadowStyle) {
        self.sm = sm
        self.md = md
        self.lg = lg
    }
}

// MARK: - Icon Size Tokens

/// Icon size tokens mirroring DesignSystem.IconSize
public struct IconSizeTokens {
    public let sm: CGFloat
    public let md: CGFloat
    public let lg: CGFloat
    public let xl: CGFloat
    public let huge: CGFloat

    public init(sm: CGFloat, md: CGFloat, lg: CGFloat, xl: CGFloat, huge: CGFloat) {
        self.sm = sm
        self.md = md
        self.lg = lg
        self.xl = xl
        self.huge = huge
    }
}

// MARK: - Animation Tokens

/// Animation tokens mirroring DesignSystem.Animation
public struct AnimationTokens {
    public let quick: Animation
    public let standard: Animation
    public let smooth: Animation
    public let bouncy: Animation

    public init(quick: Animation, standard: Animation, smooth: Animation, bouncy: Animation) {
        self.quick = quick
        self.standard = standard
        self.smooth = smooth
        self.bouncy = bouncy
    }
}

// MARK: - AnimationDelay — intentionally NOT tokenized

//
// DesignSystem.AnimationDelay (short/medium/mediumLong/long/extraLong) defines entrance-sequence
// stagger timings used as: theme.animations.smooth.delay(DesignSystem.AnimationDelay.medium).
//
// These are NOT added to AppThemeProtocol as AnimationDelayTokens because:
//   1. They are plain Double timing constants, not visual design tokens.
//   2. The hybrid pattern is semantically correct — the animation style is theme-driven,
//      but the delay is view-choreography logic that belongs with the view.
//   3. A future theme would never need different stagger delays.

// MARK: - Gradient Tokens

/// Gradient tokens for themed gradient styles
public struct GradientTokens {
    /// Score display gradient (blue to purple)
    public let scoreGradient: LinearGradient
    /// Trophy/achievement gradient (yellow to orange)
    public let trophyGradient: LinearGradient

    public init(scoreGradient: LinearGradient, trophyGradient: LinearGradient) {
        self.scoreGradient = scoreGradient
        self.trophyGradient = trophyGradient
    }
}

// MARK: - AppThemeProtocol

/// Protocol for app-wide visual theming. Conforming types supply typed token groups
/// that components read via @Environment(\.appTheme). Enables future theme variants
/// (high-contrast, seasonal, white-label) without touching component internals.
public protocol AppThemeProtocol {
    var colors: ColorTokens { get }
    var typography: TypographyTokens { get }
    var spacing: SpacingTokens { get }
    var cornerRadius: CornerRadiusTokens { get }
    var shadows: ShadowTokens { get }
    var iconSizes: IconSizeTokens { get }
    var animations: AnimationTokens { get }
    var gradients: GradientTokens { get }
}

// MARK: - DefaultTheme

/// Default theme that delegates to existing ColorPalette, Typography, and DesignSystem.
/// No visual values change — this is a thin wrapper enabling the theme environment.
public struct DefaultTheme: AppThemeProtocol {
    public init() {}

    public let colors = ColorTokens(
        primary: ColorPalette.primary,
        secondary: ColorPalette.secondary,
        success: ColorPalette.success,
        warning: ColorPalette.warning,
        error: ColorPalette.error,
        info: ColorPalette.info,
        successText: ColorPalette.successText,
        warningText: ColorPalette.warningText,
        errorText: ColorPalette.errorText,
        infoText: ColorPalette.infoText,
        textPrimary: ColorPalette.textPrimary,
        textSecondary: ColorPalette.textSecondary,
        textTertiary: ColorPalette.textTertiary,
        background: ColorPalette.background,
        backgroundSecondary: ColorPalette.backgroundSecondary,
        backgroundTertiary: ColorPalette.backgroundTertiary,
        backgroundGrouped: ColorPalette.backgroundGrouped,
        statBlue: ColorPalette.statBlue,
        statGreen: ColorPalette.statGreen,
        statPurple: ColorPalette.statPurple,
        statOrange: ColorPalette.statOrange,
        textOnPrimary: ColorPalette.textOnPrimary,
        scrim: ColorPalette.scrim
    )

    public let typography = TypographyTokens(
        h1: Typography.h1,
        h2: Typography.h2,
        h3: Typography.h3,
        h4: Typography.h4,
        bodyLarge: Typography.bodyLarge,
        bodyMedium: Typography.bodyMedium,
        bodySmall: Typography.bodySmall,
        labelLarge: Typography.labelLarge,
        labelMedium: Typography.labelMedium,
        labelSmall: Typography.labelSmall,
        captionLarge: Typography.captionLarge,
        captionMedium: Typography.captionMedium,
        captionSmall: Typography.captionSmall,
        statValue: Typography.statValue,
        button: Typography.button
    )

    public let spacing = SpacingTokens(
        xs: DesignSystem.Spacing.xs,
        sm: DesignSystem.Spacing.sm,
        md: DesignSystem.Spacing.md,
        lg: DesignSystem.Spacing.lg,
        xl: DesignSystem.Spacing.xl,
        xxl: DesignSystem.Spacing.xxl,
        xxxl: DesignSystem.Spacing.xxxl,
        huge: DesignSystem.Spacing.huge,
        section: DesignSystem.Spacing.section
    )

    public let cornerRadius = CornerRadiusTokens(
        sm: DesignSystem.CornerRadius.sm,
        md: DesignSystem.CornerRadius.md,
        lg: DesignSystem.CornerRadius.lg,
        xl: DesignSystem.CornerRadius.xl,
        full: DesignSystem.CornerRadius.full
    )

    public let shadows = ShadowTokens(
        sm: DesignSystem.Shadow.sm,
        md: DesignSystem.Shadow.md,
        lg: DesignSystem.Shadow.lg
    )

    public let iconSizes = IconSizeTokens(
        sm: DesignSystem.IconSize.sm,
        md: DesignSystem.IconSize.md,
        lg: DesignSystem.IconSize.lg,
        xl: DesignSystem.IconSize.xl,
        huge: DesignSystem.IconSize.huge
    )

    public let animations = AnimationTokens(
        quick: DesignSystem.Animation.quick,
        standard: DesignSystem.Animation.standard,
        smooth: DesignSystem.Animation.smooth,
        bouncy: DesignSystem.Animation.bouncy
    )

    public let gradients = GradientTokens(
        scoreGradient: ColorPalette.scoreGradient,
        trophyGradient: ColorPalette.trophyGradient
    )
}
