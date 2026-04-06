import SwiftUI

// MARK: - Data Source Protocol

/// Protocol for providing paginated data to `PaginatedList`.
///
/// Consumers implement this on their view model (or a dedicated data source object)
/// to supply items, loading state, and pagination hooks.
///
/// Example:
/// ```swift
/// final class MyViewModel: ObservableObject, PaginatedDataSource {
///     @Published var items: [MyItem] = []
///     @Published var isLoading = false
///     @Published var isLoadingMore = false
///     @Published var hasMorePages = true
///     @Published var error: Error?
///
///     func refresh() async { /* reload from page 1 */ }
///     func loadMore() async { /* fetch next page */ }
/// }
/// ```
public protocol PaginatedDataSource: ObservableObject {
    associatedtype Item: Identifiable

    /// The current list of loaded items.
    var items: [Item] { get }
    /// `true` during the initial load or a pull-to-refresh.
    var isLoading: Bool { get }
    /// `true` while a next-page fetch is in flight.
    var isLoadingMore: Bool { get }
    /// `false` once the server signals there are no more pages.
    var hasMorePages: Bool { get }
    /// Non-nil when the most recent load failed.
    var error: Error? { get }

    /// Reload from the beginning (pull-to-refresh / initial load).
    func refresh() async
    /// Fetch the next page of results.
    func loadMore() async
}

// MARK: - Paginated List View

/// A reusable list wrapper that provides pull-to-refresh, infinite scroll,
/// loading footers, and empty / error states out of the box.
///
/// Built on `List` + `LazyVStack` so it composes naturally with existing
/// SwiftUI list views.
///
/// ```swift
/// PaginatedList(dataSource: viewModel) { item in
///     Text(item.name)
/// }
/// ```
public struct PaginatedList<DataSource: PaginatedDataSource, RowContent: View>: View {
    @ObservedObject private var dataSource: DataSource
    private let rowContent: (DataSource.Item) -> RowContent
    private let emptyIcon: String
    private let emptyTitle: String
    private let emptyMessage: String
    private let prefetchThreshold: Int

    @Environment(\.appTheme) private var theme

    /// Creates a paginated list.
    /// - Parameters:
    ///   - dataSource: An object conforming to `PaginatedDataSource`.
    ///   - emptyIcon: SF Symbol shown when the list is empty. Defaults to `"tray"`.
    ///   - emptyTitle: Title shown in the empty state.
    ///   - emptyMessage: Message shown in the empty state.
    ///   - prefetchThreshold: How many items before the end to trigger `loadMore`. Defaults to 3.
    ///   - rowContent: A view builder producing each row.
    public init(
        dataSource: DataSource,
        emptyIcon: String = "tray",
        emptyTitle: String = "Nothing Here",
        emptyMessage: String = "There are no items to display.",
        prefetchThreshold: Int = 3,
        @ViewBuilder rowContent: @escaping (DataSource.Item) -> RowContent
    ) {
        self.dataSource = dataSource
        self.rowContent = rowContent
        self.emptyIcon = emptyIcon
        self.emptyTitle = emptyTitle
        self.emptyMessage = emptyMessage
        self.prefetchThreshold = prefetchThreshold
    }

    public var body: some View {
        Group {
            if dataSource.isLoading && dataSource.items.isEmpty {
                LoadingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = dataSource.error, dataSource.items.isEmpty {
                ErrorView(error: error) {
                    Task { await dataSource.refresh() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if dataSource.items.isEmpty && !dataSource.isLoading {
                EmptyStateView(
                    icon: emptyIcon,
                    title: emptyTitle,
                    message: emptyMessage,
                    actionTitle: "Refresh",
                    action: { Task { await dataSource.refresh() } }
                )
            } else {
                listContent
            }
        }
        .animation(theme.animations.standard, value: dataSource.items.count)
        .accessibilityIdentifier("paginatedList")
    }

    private var listContent: some View {
        List {
            ForEach(dataSource.items) { item in
                rowContent(item)
                    .onAppear {
                        onItemAppear(item)
                    }
            }

            if dataSource.isLoadingMore {
                LoadingFooter()
                    .listRowSeparator(.hidden)
            }

            if let error = dataSource.error, !dataSource.items.isEmpty {
                InlineErrorRow(error: error) {
                    Task { await dataSource.loadMore() }
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await dataSource.refresh()
        }
    }

    private func onItemAppear(_ item: DataSource.Item) {
        guard dataSource.hasMorePages,
              !dataSource.isLoadingMore,
              dataSource.error == nil else { return }

        let items = dataSource.items
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }

        if index >= items.count - prefetchThreshold {
            Task { await dataSource.loadMore() }
        }
    }
}

// MARK: - Loading Footer

/// A compact loading indicator shown at the bottom of the list during pagination.
public struct LoadingFooter: View {
    @Environment(\.appTheme) private var theme

    public init() {}

    public var body: some View {
        HStack(spacing: theme.spacing.sm) {
            ProgressView()
            Text("Loading more…")
                .font(theme.typography.captionLarge)
                .foregroundColor(theme.colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading more items")
        .accessibilityIdentifier("paginatedList.loadingFooter")
    }
}

// MARK: - Inline Error Row

/// A compact error row shown at the bottom of the list when a pagination fetch fails.
struct InlineErrorRow: View {
    let error: Error
    let retryAction: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: theme.spacing.sm) {
            Text("Couldn't load more items")
                .font(theme.typography.captionLarge)
                .foregroundColor(theme.colors.textSecondary)

            Button(action: retryAction) {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(theme.typography.labelSmall)
            }
            .accessibilityIdentifier("paginatedList.retryButton")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacing.lg)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("paginatedList.inlineError")
    }
}

// MARK: - Previews

#if DEBUG
private struct PreviewItem: Identifiable {
    let id: Int
    let title: String
}

@MainActor
private final class PreviewDataSource: PaginatedDataSource {
    @Published var items: [PreviewItem] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMorePages = true
    @Published var error: Error?

    private var page = 0

    init(initialItems: [PreviewItem] = []) {
        self.items = initialItems
    }

    func refresh() async {
        isLoading = true
        try? await Task.sleep(for: .seconds(1))
        page = 0
        items = (1...20).map { PreviewItem(id: $0, title: "Item \($0)") }
        hasMorePages = true
        isLoading = false
    }

    func loadMore() async {
        isLoadingMore = true
        try? await Task.sleep(for: .seconds(1))
        page += 1
        let start = items.count + 1
        items += (start...(start + 19)).map { PreviewItem(id: $0, title: "Item \($0)") }
        hasMorePages = page < 3
        isLoadingMore = false
    }
}

#Preview("Populated") {
    let ds = PreviewDataSource(
        initialItems: (1...20).map { PreviewItem(id: $0, title: "Item \($0)") }
    )
    PaginatedList(dataSource: ds) { item in
        Text(item.title)
    }
}

#Preview("Empty") {
    PaginatedList(
        dataSource: PreviewDataSource(),
        emptyTitle: "No Results",
        emptyMessage: "Try a different search."
    ) { item in
        Text(item.title)
    }
}

#Preview("Loading") {
    let ds = PreviewDataSource()
    let _ = { ds.isLoading = true }()
    PaginatedList(dataSource: ds) { item in
        Text(item.title)
    }
}
#endif
