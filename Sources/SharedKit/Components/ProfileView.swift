import SwiftUI

#if canImport(UIKit)
/// A reusable profile screen displaying user info, favorite comedians, and sign-out.
///
/// Uses `ProfileViewModel` for state and delegates sign-out to the auth flow.
///
/// ## Usage
/// ```swift
/// ProfileView(viewModel: profileViewModel)
/// ```
public struct ProfileView: View {
    @ObservedObject private var viewModel: ProfileViewModel

    @Environment(\.appTheme) private var theme

    public init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing.xl) {
                // User Info
                VStack(spacing: theme.spacing.sm) {
                    Text(viewModel.userName)
                        .font(theme.typography.h1)
                        .foregroundColor(theme.colors.textPrimary)
                        .accessibilityIdentifier("profile_name")

                    Text(viewModel.userEmail)
                        .font(theme.typography.bodyMedium)
                        .foregroundColor(theme.colors.textSecondary)
                        .accessibilityIdentifier("profile_email")
                }
                .padding(.top, theme.spacing.huge)

                // Favorite Comedians
                if !viewModel.favoriteComedians.isEmpty {
                    VStack(alignment: .leading, spacing: theme.spacing.md) {
                        Text("Favorite Comedians")
                            .font(theme.typography.h3)
                            .foregroundColor(theme.colors.textPrimary)
                            .accessibilityIdentifier("profile_comediansHeader")

                        ForEach(viewModel.favoriteComedians) { comedian in
                            HStack(spacing: theme.spacing.sm) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(theme.colors.secondary)
                                    .accessibilityHidden(true)
                                Text(comedian.name)
                                    .font(theme.typography.bodyMedium)
                                    .foregroundColor(theme.colors.textPrimary)
                            }
                            .padding(.vertical, theme.spacing.xs)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Error banner
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                        .font(theme.typography.captionLarge)
                        .foregroundColor(theme.colors.errorText)
                        .padding(theme.spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.colors.error.opacity(0.1))
                        .cornerRadius(theme.cornerRadius.sm)
                        .accessibilityIdentifier("profile_errorBanner")
                }

                // Sign out button
                PrimaryButton(
                    title: "Sign Out",
                    action: { Task { await viewModel.signOut() } },
                    isLoading: viewModel.isLoading,
                    accessibilityId: "profile_signOutButton"
                )
            }
            .padding(.horizontal, theme.spacing.xl)
        }
        .task {
            await viewModel.loadProfile()
        }
    }
}

#Preview {
    Text("ProfileView requires ProfileViewModel with dependencies")
}
#endif
