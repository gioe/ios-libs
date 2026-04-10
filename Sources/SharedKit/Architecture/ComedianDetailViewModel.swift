import Combine
import Foundation

/// ViewModel for the comedian detail screen.
///
/// Loads a single comedian's full details including show history and manages favorite toggle.
/// When a `FavoritesManager` is provided, favorite toggling is delegated to it for
/// optimistic UI, offline queuing, and cross-screen state sync. Without one, falls back
/// to direct service calls with local optimistic update/rollback.
@MainActor
public class ComedianDetailViewModel: BaseViewModel {
    // MARK: - Published State

    @Published public var detail: ComedianDetail?
    @Published public var isFavorite: Bool = false

    // MARK: - Dependencies

    private let comedianService: any ComedianServiceProtocol
    private let comedianId: Int
    private let favoritesManager: (any FavoritesManagerProtocol)?

    // MARK: - Navigation

    /// Callback invoked when the user taps a show in the history list.
    public var onShowSelected: ((Show) -> Void)?

    // MARK: - Initialization

    public init(
        comedianId: Int,
        comedianService: any ComedianServiceProtocol,
        favoritesManager: (any FavoritesManagerProtocol)? = nil,
        errorRecorder: ErrorRecorder? = nil
    ) {
        self.comedianId = comedianId
        self.comedianService = comedianService
        self.favoritesManager = favoritesManager
        super.init(errorRecorder: errorRecorder)

        // Subscribe to cross-screen favorite changes
        if let favoritesManager {
            favoritesManager.favoriteChanged
                .filter { [comedianId] id in id == comedianId }
                .sink { [weak self] _ in
                    guard let self else { return }
                    self.isFavorite = favoritesManager.isFavorite(comedianId: comedianId)
                }
                .store(in: &cancellables)
        }
    }

    // MARK: - Loading

    /// Loads the comedian detail from the service.
    public func load() async {
        guard !isLoading else { return }
        clearError()
        setLoading(true)

        do {
            let result = try await comedianService.getComedian(id: comedianId)
            detail = result
            isFavorite = result.comedian.isFavorite
            favoritesManager?.setInitialState(comedianId: comedianId, isFavorite: result.comedian.isFavorite)
            setLoading(false)
        } catch {
            handleError(error, context: "getComedian") { [weak self] in
                await self?.load()
            }
        }
    }

    // MARK: - Actions

    /// Toggles the favorite status for this comedian.
    ///
    /// When a `FavoritesManager` is available, delegates to it for offline queue
    /// integration and cross-screen sync. Otherwise falls back to direct service call.
    public func toggleFavorite() async {
        if let favoritesManager {
            await favoritesManager.toggleFavorite(comedianId: comedianId)
        } else {
            let newValue = !isFavorite
            isFavorite = newValue // Optimistic update

            do {
                try await comedianService.toggleFavorite(comedianId: comedianId, isFavorite: newValue)
            } catch {
                isFavorite = !newValue // Revert on failure
                handleError(error, context: "toggleFavorite")
            }
        }
    }

    /// Called when the user taps a show in the history list.
    public func selectShow(_ show: Show) {
        onShowSelected?(show)
    }
}
