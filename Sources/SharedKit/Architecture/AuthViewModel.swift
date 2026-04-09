import Foundation

/// The current screen in the authentication flow.
public enum AuthScreen {
    case signIn
    case signUp
}

/// ViewModel managing the authentication flow (sign-in, sign-up, sign-out).
///
/// Uses `AuthServiceProtocol` for API calls and `AuthTokenManager` for token persistence.
/// Consumer apps inject both dependencies; the ViewModel handles validation, loading state,
/// and screen transitions.
///
/// ## Usage
/// ```swift
/// let tokenManager = AuthTokenManager(secureStorage: KeychainStorage())
/// let authService = MyAuthService()
/// let viewModel = AuthViewModel(
///     authService: authService,
///     tokenManager: tokenManager
/// )
/// ```
@MainActor
public class AuthViewModel: BaseViewModel {
    // MARK: - Form Fields

    @Published public var email: String = ""
    @Published public var password: String = ""
    @Published public var name: String = ""
    @Published public var confirmPassword: String = ""
    @Published public var currentScreen: AuthScreen = .signIn

    // MARK: - Dependencies

    private let authService: any AuthServiceProtocol
    public let tokenManager: AuthTokenManager

    /// Callback invoked after successful authentication (sign-in or sign-up).
    /// Consumer apps use this to sync tokens with middleware or perform post-login setup.
    public var onAuthenticated: ((AuthTokens) async -> Void)?

    /// Callback invoked after sign-out completes.
    /// Consumer apps use this to clear middleware tokens or perform post-logout cleanup.
    public var onSignedOut: (() async -> Void)?

    // MARK: - Initialization

    public init(
        authService: any AuthServiceProtocol,
        tokenManager: AuthTokenManager,
        errorRecorder: ErrorRecorder? = nil
    ) {
        self.authService = authService
        self.tokenManager = tokenManager
        super.init(errorRecorder: errorRecorder)
    }

    // MARK: - Validation

    public var emailError: String? {
        validationError(for: email, using: Validators.validateEmail)
    }

    public var passwordError: String? {
        validationError(for: password, using: Validators.validatePassword)
    }

    public var nameError: String? {
        validationError(for: name, using: Validators.validateName)
    }

    public var confirmPasswordError: String? {
        validationError(for: confirmPassword, matching: password, using: Validators.validatePasswordConfirmation)
    }

    public var isSignInFormValid: Bool {
        Validators.validateEmail(email).isValid
            && Validators.validatePassword(password).isValid
    }

    public var isSignUpFormValid: Bool {
        Validators.validateName(name).isValid
            && Validators.validateEmail(email).isValid
            && Validators.validatePassword(password).isValid
            && Validators.validatePasswordConfirmation(password, confirmPassword).isValid
    }

    // MARK: - Actions

    public func signIn() async {
        clearError()
        setLoading(true)

        do {
            let tokens = try await authService.signIn(email: email, password: password)
            try tokenManager.storeTokens(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
            await onAuthenticated?(tokens)
            setLoading(false)
        } catch {
            handleError(error, context: "signIn") { [weak self] in
                await self?.signIn()
            }
        }
    }

    public func signUp() async {
        clearError()
        setLoading(true)

        do {
            let tokens = try await authService.signUp(name: name, email: email, password: password)
            try tokenManager.storeTokens(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
            await onAuthenticated?(tokens)
            setLoading(false)
        } catch {
            handleError(error, context: "signUp") { [weak self] in
                await self?.signUp()
            }
        }
    }

    public func signOut() async {
        do {
            try tokenManager.clearTokens()
        } catch {
            handleError(error, context: "signOut")
            return
        }
        await onSignedOut?()
        resetForm()
        currentScreen = .signIn
    }

    public func switchToSignUp() {
        clearError()
        currentScreen = .signUp
    }

    public func switchToSignIn() {
        clearError()
        currentScreen = .signIn
    }

    // MARK: - Private

    private func resetForm() {
        email = ""
        password = ""
        name = ""
        confirmPassword = ""
    }
}
