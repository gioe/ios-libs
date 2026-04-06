import SwiftUI

/// A reusable loading indicator view
public struct LoadingView: View {
    public var message: String = "Loading..."

    @Environment(\.appTheme) private var theme

    public init(message: String = "Loading...") {
        self.message = message
    }

    public var body: some View {
        VStack(spacing: theme.spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
                .accessibilityHidden(true) // Visual indicator only
            Text(message)
                .font(theme.typography.bodySmall)
                .foregroundColor(theme.colors.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
        .accessibilityIdentifier("common.loadingView")
    }
}

#Preview {
    LoadingView()
}

#Preview("Custom Message") {
    LoadingView(message: "Fetching your results...")
}
