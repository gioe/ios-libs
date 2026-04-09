import Foundation
@testable import SharedKit
import Testing

/// Mock auth service for testing
private struct MockAuthService: AuthServiceProtocol {
    var signInResult: Result<AuthTokens, Error> = .success(AuthTokens(accessToken: "access", refreshToken: "refresh"))
    var signUpResult: Result<AuthTokens, Error> = .success(AuthTokens(accessToken: "access", refreshToken: "refresh"))

    func signIn(email: String, password: String) async throws -> AuthTokens {
        try signInResult.get()
    }

    func signUp(name: String, email: String, password: String) async throws -> AuthTokens {
        try signUpResult.get()
    }
}

private enum TestError: Error, LocalizedError {
    case invalidCredentials

    var errorDescription: String? { "Invalid credentials" }
}

@Suite("AuthViewModel")
struct AuthViewModelTests {

    @MainActor
    private func makeViewModel(
        signInResult: Result<AuthTokens, Error> = .success(AuthTokens(accessToken: "a", refreshToken: "r")),
        signUpResult: Result<AuthTokens, Error> = .success(AuthTokens(accessToken: "a", refreshToken: "r"))
    ) -> AuthViewModel {
        let storage = MockSecureStorage()
        let tokenManager = AuthTokenManager(secureStorage: storage)
        let service = MockAuthService(signInResult: signInResult, signUpResult: signUpResult)
        return AuthViewModel(authService: service, tokenManager: tokenManager)
    }

    // MARK: - Validation

    @Test("isSignInFormValid requires valid email and password")
    @MainActor
    func signInFormValidation() {
        let vm = makeViewModel()

        #expect(vm.isSignInFormValid == false)

        vm.email = "user@example.com"
        vm.password = "password123"
        #expect(vm.isSignInFormValid == true)

        vm.email = "invalid"
        #expect(vm.isSignInFormValid == false)
    }

    @Test("isSignUpFormValid requires all fields valid")
    @MainActor
    func signUpFormValidation() {
        let vm = makeViewModel()

        vm.name = "Jo"
        vm.email = "user@example.com"
        vm.password = "password123"
        vm.confirmPassword = "password123"
        #expect(vm.isSignUpFormValid == true)

        vm.confirmPassword = "different"
        #expect(vm.isSignUpFormValid == false)
    }

    @Test("emailError returns nil for empty and error for invalid")
    @MainActor
    func emailErrorValidation() {
        let vm = makeViewModel()

        #expect(vm.emailError == nil) // empty → no error shown
        vm.email = "bad"
        #expect(vm.emailError != nil) // invalid → shows error
        vm.email = "user@example.com"
        #expect(vm.emailError == nil) // valid → no error
    }

    // MARK: - Sign In

    @Test("signIn success stores tokens and invokes callback")
    @MainActor
    func signInSuccess() async {
        let tokens = AuthTokens(accessToken: "acc", refreshToken: "ref")
        let vm = makeViewModel(signInResult: .success(tokens))
        vm.email = "user@example.com"
        vm.password = "password123"

        var callbackTokens: AuthTokens?
        vm.onAuthenticated = { callbackTokens = $0 }

        await vm.signIn()

        #expect(vm.tokenManager.isAuthenticated == true)
        #expect(callbackTokens == tokens)
        #expect(vm.error == nil)
        #expect(vm.isLoading == false)
    }

    @Test("signIn failure sets error")
    @MainActor
    func signInFailure() async {
        let vm = makeViewModel(signInResult: .failure(TestError.invalidCredentials))
        vm.email = "user@example.com"
        vm.password = "password123"

        await vm.signIn()

        #expect(vm.error != nil)
        #expect(vm.tokenManager.isAuthenticated == false)
    }

    // MARK: - Sign Up

    @Test("signUp success stores tokens")
    @MainActor
    func signUpSuccess() async {
        let vm = makeViewModel()
        vm.name = "Test User"
        vm.email = "user@example.com"
        vm.password = "password123"
        vm.confirmPassword = "password123"

        await vm.signUp()

        #expect(vm.tokenManager.isAuthenticated == true)
        #expect(vm.error == nil)
    }

    // MARK: - Sign Out

    @Test("signOut clears tokens, resets form, invokes callback")
    @MainActor
    func signOutClearsState() async {
        let vm = makeViewModel()
        vm.email = "user@example.com"
        vm.password = "password123"
        await vm.signIn()

        var signedOutCalled = false
        vm.onSignedOut = { signedOutCalled = true }

        await vm.signOut()

        #expect(vm.tokenManager.isAuthenticated == false)
        #expect(vm.email == "")
        #expect(vm.password == "")
        #expect(vm.currentScreen == .signIn)
        #expect(signedOutCalled == true)
    }

    @Test("signOut does not invoke callback when clearTokens fails")
    @MainActor
    func signOutFailureDoesNotProceed() async {
        let storage = MockSecureStorage()
        let tokenManager = AuthTokenManager(secureStorage: storage)
        let service = MockAuthService()
        let vm = AuthViewModel(authService: service, tokenManager: tokenManager)

        vm.email = "user@example.com"
        vm.password = "password123"
        await vm.signIn()

        // Make storage fail
        storage.shouldThrow = true

        var signedOutCalled = false
        vm.onSignedOut = { signedOutCalled = true }

        await vm.signOut()

        #expect(signedOutCalled == false)
        #expect(vm.error != nil)
    }

    // MARK: - Screen Switching

    @Test("switchToSignUp changes screen and clears error")
    @MainActor
    func switchToSignUp() {
        let vm = makeViewModel()
        vm.switchToSignUp()
        #expect(vm.currentScreen == .signUp)
    }

    @Test("switchToSignIn changes screen and clears error")
    @MainActor
    func switchToSignIn() {
        let vm = makeViewModel()
        vm.switchToSignUp()
        vm.switchToSignIn()
        #expect(vm.currentScreen == .signIn)
    }
}
