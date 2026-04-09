import SwiftUI

#if canImport(UIKit)
/// A reusable show search and listing screen with filters for date range, comedian, and club.
///
/// Uses `ShowListViewModel` for state and `PaginatedList` for infinite scrolling.
///
/// ## Usage
/// ```swift
/// ShowListView(viewModel: showListViewModel)
/// ```
public struct ShowListView: View {
    @ObservedObject private var viewModel: ShowListViewModel

    @Environment(\.appTheme) private var theme

    @State private var searchText: String = ""
    @State private var showFilters: Bool = false

    public init(viewModel: ShowListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            SearchBar(
                text: $searchText,
                placeholder: "Search shows…",
                onDebouncedChange: { text in
                    Task { await viewModel.updateSearchText(text) }
                },
                accessibilityId: "showList_searchBar"
            )
            .padding(.horizontal, theme.spacing.md)
            .padding(.vertical, theme.spacing.sm)

            filterBar

            PaginatedList(
                dataSource: viewModel,
                emptyIcon: "theatermasks",
                emptyTitle: "No Shows Found",
                emptyMessage: "Try adjusting your filters or search terms.",
                rowContent: { show in
                    ShowCardView(show: show, theme: theme)
                        .contentShape(Rectangle())
                        .onTapGesture { viewModel.selectShow(show) }
                        .listRowInsets(EdgeInsets(
                            top: theme.spacing.xs,
                            leading: theme.spacing.md,
                            bottom: theme.spacing.xs,
                            trailing: theme.spacing.md
                        ))
                        .accessibilityIdentifier("showList_card_\(show.id)")
                }
            )
        }
        .sheet(isPresented: $showFilters) {
            ShowFilterSheet(
                filters: viewModel.filters,
                onApply: { filters in
                    showFilters = false
                    searchText = filters.searchText
                    Task { await viewModel.applyFilters(filters) }
                },
                onClear: {
                    showFilters = false
                    searchText = ""
                    Task { await viewModel.clearFilters() }
                }
            )
        }
        .task {
            if viewModel.items.isEmpty {
                await viewModel.refresh()
            }
        }
    }

    private var filterBar: some View {
        HStack {
            if !viewModel.filters.isEmpty {
                activeFilterChips
            }

            Spacer()

            Button {
                showFilters = true
            } label: {
                Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                    .font(theme.typography.labelSmall)
                    .foregroundColor(viewModel.filters.isEmpty ? theme.colors.textSecondary : theme.colors.primary)
            }
            .accessibilityIdentifier("showList_filterButton")
        }
        .padding(.horizontal, theme.spacing.md)
        .padding(.vertical, theme.spacing.xs)
    }

    @ViewBuilder
    private var activeFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacing.xs) {
                if viewModel.filters.startDate != nil || viewModel.filters.endDate != nil {
                    FilterChip(label: "Date Range", theme: theme)
                }
                if let comedian = viewModel.filters.comedian {
                    FilterChip(label: comedian, theme: theme)
                }
                if let club = viewModel.filters.club {
                    FilterChip(label: club, theme: theme)
                }
            }
        }
    }
}

// MARK: - Show Card

struct ShowCardView: View {
    let show: Show
    let theme: any AppThemeProtocol

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            // Comedian lineup
            Text(show.comedians.joined(separator: ", "))
                .font(theme.typography.h4)
                .foregroundColor(theme.colors.textPrimary)
                .lineLimit(2)
                .accessibilityIdentifier("showCard_comedians")

            // Venue
            HStack(spacing: theme.spacing.xs) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(theme.colors.secondary)
                    .accessibilityHidden(true)
                Text(show.venueName)
                    .font(theme.typography.bodyMedium)
                    .foregroundColor(theme.colors.textSecondary)
            }
            .accessibilityIdentifier("showCard_venue")

            // Date/time
            HStack(spacing: theme.spacing.xs) {
                Image(systemName: "calendar")
                    .foregroundColor(theme.colors.secondary)
                    .accessibilityHidden(true)
                Text(Self.dateFormatter.string(from: show.date))
                    .font(theme.typography.bodySmall)
                    .foregroundColor(theme.colors.textSecondary)
            }
            .accessibilityIdentifier("showCard_date")

            // Ticket link
            if let ticketURL = show.ticketURL {
                Link(destination: ticketURL) {
                    Label("Get Tickets", systemImage: "ticket")
                        .font(theme.typography.labelSmall)
                        .foregroundColor(theme.colors.primary)
                }
                .accessibilityIdentifier("showCard_ticketLink")
            }
        }
        .padding(theme.spacing.md)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let theme: any AppThemeProtocol

    var body: some View {
        Text(label)
            .font(theme.typography.captionLarge)
            .foregroundColor(theme.colors.primary)
            .padding(.horizontal, theme.spacing.sm)
            .padding(.vertical, theme.spacing.xxs)
            .background(theme.colors.primary.opacity(0.1))
            .cornerRadius(theme.cornerRadius.sm)
    }
}

// MARK: - Filter Sheet

struct ShowFilterSheet: View {
    @State var filters: ShowSearchFilters
    let onApply: (ShowSearchFilters) -> Void
    let onClear: () -> Void

    @Environment(\.appTheme) private var theme

    @State private var useDateRange: Bool = false
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var comedian: String = ""
    @State private var club: String = ""

    init(filters: ShowSearchFilters, onApply: @escaping (ShowSearchFilters) -> Void, onClear: @escaping () -> Void) {
        self._filters = State(initialValue: filters)
        self.onApply = onApply
        self.onClear = onClear
        self._useDateRange = State(initialValue: filters.startDate != nil || filters.endDate != nil)
        self._startDate = State(initialValue: filters.startDate ?? Date())
        self._endDate = State(initialValue: filters.endDate ?? Date())
        self._comedian = State(initialValue: filters.comedian ?? "")
        self._club = State(initialValue: filters.club ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Date Range") {
                    Toggle("Filter by date", isOn: $useDateRange)
                        .accessibilityIdentifier("filter_dateToggle")
                    if useDateRange {
                        DatePicker("From", selection: $startDate, displayedComponents: .date)
                            .accessibilityIdentifier("filter_startDate")
                        DatePicker("To", selection: $endDate, displayedComponents: .date)
                            .accessibilityIdentifier("filter_endDate")
                    }
                }

                Section("Comedian") {
                    TextField("Comedian name", text: $comedian)
                        .accessibilityIdentifier("filter_comedian")
                }

                Section("Club / Venue") {
                    TextField("Club name", text: $club)
                        .accessibilityIdentifier("filter_club")
                }
            }
            .navigationTitle("Filters")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") { onClear() }
                        .accessibilityIdentifier("filter_clearButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        var updated = filters
                        updated.startDate = useDateRange ? startDate : nil
                        updated.endDate = useDateRange ? endDate : nil
                        updated.comedian = comedian.isEmpty ? nil : comedian
                        updated.club = club.isEmpty ? nil : club
                        onApply(updated)
                    }
                    .accessibilityIdentifier("filter_applyButton")
                }
            }
        }
    }
}

#Preview {
    Text("ShowListView requires ShowListViewModel with dependencies")
}
#endif
