import Foundation

/// ViewModel for the comedian detail screen.
///
/// Loads a single comedian's full details including show history and manages favorite toggle.
@MainActor
public class ComedianDetailViewModel: BaseViewModel {
    // MARK: - Published State

    @Published public var detail: ComedianDetail?
    @Published public var isFavorite: Bool = false

    // MARK: - Dependencies

    private let comedianService: any ComedianServiceProtocol
    private let comedianId: Int

    // MARK: - Navigation

    /// Callback invoked when the user taps a show in the history list.
    public var onShowSelected: ((Show) -> Void)?

    // MARK: - Initialization

    public init(
        comedianId: Int,
        comedianService: any ComedianServiceProtocol,
        errorRecorder: ErrorRecorder? = nil
    ) {
        self.comedianId = comedianId
        self.comedianService = comedianService
        super.init(errorRecorder: errorRecorder)
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
            setLoading(false)
        } catch {
            handleError(error, context: "getComedian") { [weak self] in
                await self?.load()
            }
        }
    }

    // MARK: - Actions

    /// Toggles the favorite status for this comedian.
    public func toggleFavorite() async {
        let newValue = !isFavorite
        isFavorite = newValue // Optimistic update

        do {
            try await comedianService.toggleFavorite(comedianId: comedianId, isFavorite: newValue)
        } catch {
            isFavorite = !newValue // Revert on failure
            handleError(error, context: "toggleFavorite")
        }
    }

    /// Called when the user taps a show in the history list.
    public func selectShow(_ show: Show) {
        onShowSelected?(show)
    }
}
