import Foundation

/// Lightweight comedian model for display in the profile screen.
///
/// Consumer apps map their API response types to this struct.
public struct FavoriteComedian: Identifiable, Sendable, Equatable {
    public let id: Int
    public let name: String

    public init(id: Int, name: String) {
        self.id = id
        self.name = name
    }
}

/// Protocol defining the data contract for the profile screen.
///
/// Consumer apps implement this to connect the profile view to their backend.
/// The protocol is transport-agnostic — implementations may use `APIClient`,
/// `URLSession`, or any other networking layer.
public protocol ProfileServiceProtocol: Sendable {
    /// Fetches the current user's display name and email.
    func getUserProfile() async throws -> (name: String, email: String)

    /// Fetches the user's favorite comedians.
    func getFavoriteComedians() async throws -> [FavoriteComedian]
}

/// ViewModel for the profile screen.
///
/// Loads user info and favorite comedians via `ProfileServiceProtocol`,
/// and delegates sign-out to `AuthViewModel`.
@MainActor
public class ProfileViewModel: BaseViewModel {
    // MARK: - Published State

    @Published public var userName: String = ""
    @Published public var userEmail: String = ""
    @Published public var favoriteComedians: [FavoriteComedian] = []

    // MARK: - Dependencies

    private let profileService: any ProfileServiceProtocol
    private let authViewModel: AuthViewModel

    // MARK: - Initialization

    public init(
        profileService: any ProfileServiceProtocol,
        authViewModel: AuthViewModel,
        errorRecorder: ErrorRecorder? = nil
    ) {
        self.profileService = profileService
        self.authViewModel = authViewModel
        super.init(errorRecorder: errorRecorder)
    }

    // MARK: - Actions

    public func loadProfile() async {
        clearError()
        setLoading(true)

        do {
            let profile = try await profileService.getUserProfile()
            userName = profile.name
            userEmail = profile.email

            let comedians = try await profileService.getFavoriteComedians()
            favoriteComedians = comedians
            setLoading(false)
        } catch {
            handleError(error, context: "loadProfile") { [weak self] in
                await self?.loadProfile()
            }
        }
    }

    public func signOut() async {
        await authViewModel.signOut()
    }
}
