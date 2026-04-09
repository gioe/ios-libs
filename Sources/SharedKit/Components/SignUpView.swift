import SwiftUI

#if canImport(UIKit)
/// A reusable sign-up screen with name, email, password, and confirmation fields.
///
/// Uses `CustomTextField` and `PrimaryButton` from the SharedKit design system.
/// Displays inline validation errors and an error banner for API failures.
///
/// ## Usage
/// ```swift
/// SignUpView(viewModel: authViewModel)
/// ```
public struct SignUpView: View {
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
                    Text("Create Account")
                        .font(theme.typography.h1)
                        .foregroundColor(theme.colors.textPrimary)

                    Text("Sign up to get started")
                        .font(theme.typography.bodyMedium)
                        .foregroundColor(theme.colors.textSecondary)
                }
                .padding(.top, theme.spacing.huge)

                // Form
                VStack(spacing: theme.spacing.lg) {
                    VStack(alignment: .leading, spacing: theme.spacing.xs) {
                        CustomTextField(
                            title: "Name",
                            placeholder: "Enter your name",
                            text: $viewModel.name,
                            accessibilityId: "signUp_name",
                            submitLabel: .next
                        )

                        if let error = viewModel.nameError {
                            Text(error)
                                .font(theme.typography.captionMedium)
                                .foregroundColor(theme.colors.error)
                                .accessibilityIdentifier("signUp_nameError")
                        }
                    }

                    VStack(alignment: .leading, spacing: theme.spacing.xs) {
                        CustomTextField(
                            title: "Email",
                            placeholder: "Enter your email",
                            text: $viewModel.email,
                            keyboardType: .emailAddress,
                            autocapitalization: .never,
                            accessibilityId: "signUp_email",
                            submitLabel: .next
                        )

                        if let error = viewModel.emailError {
                            Text(error)
                                .font(theme.typography.captionMedium)
                                .foregroundColor(theme.colors.error)
                                .accessibilityIdentifier("signUp_emailError")
                        }
                    }

                    VStack(alignment: .leading, spacing: theme.spacing.xs) {
                        CustomTextField(
                            title: "Password",
                            placeholder: "Create a password",
                            text: $viewModel.password,
                            isSecure: true,
                            accessibilityId: "signUp_password",
                            submitLabel: .next
                        )

                        if let error = viewModel.passwordError {
                            Text(error)
                                .font(theme.typography.captionMedium)
                                .foregroundColor(theme.colors.error)
                                .accessibilityIdentifier("signUp_passwordError")
                        }
                    }

                    VStack(alignment: .leading, spacing: theme.spacing.xs) {
                        CustomTextField(
                            title: "Confirm Password",
                            placeholder: "Confirm your password",
                            text: $viewModel.confirmPassword,
                            isSecure: true,
                            accessibilityId: "signUp_confirmPassword",
                            submitLabel: .go,
                            onSubmit: {
                                guard viewModel.isSignUpFormValid else { return }
                                Task { await viewModel.signUp() }
                            }
                        )

                        if let error = viewModel.confirmPasswordError {
                            Text(error)
                                .font(theme.typography.captionMedium)
                                .foregroundColor(theme.colors.error)
                                .accessibilityIdentifier("signUp_confirmPasswordError")
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
                        .accessibilityIdentifier("signUp_errorBanner")
                }

                // Sign up button
                PrimaryButton(
                    title: "Create Account",
                    action: { Task { await viewModel.signUp() } },
                    isLoading: viewModel.isLoading,
                    isDisabled: !viewModel.isSignUpFormValid,
                    accessibilityId: "signUp_button"
                )

                // Switch to sign in
                Button {
                    viewModel.switchToSignIn()
                } label: {
                    HStack(spacing: theme.spacing.xs) {
                        Text("Already have an account?")
                            .foregroundColor(theme.colors.textSecondary)
                        Text("Sign In")
                            .fontWeight(.semibold)
                            .foregroundColor(theme.colors.primary)
                    }
                    .font(theme.typography.bodySmall)
                }
                .accessibilityIdentifier("signUp_switchToSignIn")
            }
            .padding(.horizontal, theme.spacing.xl)
        }
    }
}

#Preview {
    Text("SignUpView requires AuthViewModel with dependencies")
}
#endif
