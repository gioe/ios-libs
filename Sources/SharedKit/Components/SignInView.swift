import SwiftUI

#if canImport(UIKit)
/// A reusable sign-in screen with email/password fields and validation.
///
/// Uses `CustomTextField` and `PrimaryButton` from the SharedKit design system.
/// Displays inline validation errors and an error banner for API failures.
///
/// ## Usage
/// ```swift
/// SignInView(viewModel: authViewModel)
/// ```
public struct SignInView: View {
    @ObservedObject private var viewModel: AuthViewModel

    @Environment(\.appTheme) private var theme

    public init(viewModel: AuthViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing.xl) {
                // Header
                VStack(spacing: theme.spacing.sm) {
                    Text("Welcome Back")
                        .font(theme.typography.h1)
                        .foregroundColor(theme.colors.textPrimary)

                    Text("Sign in to your account")
                        .font(theme.typography.bodyMedium)
                        .foregroundColor(theme.colors.textSecondary)
                }
                .padding(.top, theme.spacing.huge)

                // Form
                VStack(spacing: theme.spacing.lg) {
                    VStack(alignment: .leading, spacing: theme.spacing.xs) {
                        CustomTextField(
                            title: "Email",
                            placeholder: "Enter your email",
                            text: $viewModel.email,
                            keyboardType: .emailAddress,
                            autocapitalization: .never,
                            accessibilityId: "signIn_email",
                            submitLabel: .next
                        )

                        if let error = viewModel.emailError {
                            Text(error)
                                .font(theme.typography.captionMedium)
                                .foregroundColor(theme.colors.error)
                                .accessibilityIdentifier("signIn_emailError")
                        }
                    }

                    VStack(alignment: .leading, spacing: theme.spacing.xs) {
                        CustomTextField(
                            title: "Password",
                            placeholder: "Enter your password",
                            text: $viewModel.password,
                            isSecure: true,
                            accessibilityId: "signIn_password",
                            submitLabel: .go,
                            onSubmit: {
                                guard viewModel.isSignInFormValid else { return }
                                Task { await viewModel.signIn() }
                            }
                        )

                        if let error = viewModel.passwordError {
                            Text(error)
                                .font(theme.typography.captionMedium)
                                .foregroundColor(theme.colors.error)
                                .accessibilityIdentifier("signIn_passwordError")
                        }
                    }
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
                        .accessibilityIdentifier("signIn_errorBanner")
                }

                // Sign in button
                PrimaryButton(
                    title: "Sign In",
                    action: { Task { await viewModel.signIn() } },
                    isLoading: viewModel.isLoading,
                    isDisabled: !viewModel.isSignInFormValid,
                    accessibilityId: "signIn_button"
                )

                // Switch to sign up
                Button {
                    viewModel.switchToSignUp()
                } label: {
                    HStack(spacing: theme.spacing.xs) {
                        Text("Don't have an account?")
                            .foregroundColor(theme.colors.textSecondary)
                        Text("Sign Up")
                            .fontWeight(.semibold)
                            .foregroundColor(theme.colors.primary)
                    }
                    .font(theme.typography.bodySmall)
                }
                .accessibilityIdentifier("signIn_switchToSignUp")
            }
            .padding(.horizontal, theme.spacing.xl)
        }
    }
}

#Preview {
    // Preview requires a mock auth service
    Text("SignInView requires AuthViewModel with dependencies")
}
#endif
