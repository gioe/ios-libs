import SwiftUI

#if canImport(UIKit)
/// A reusable club search and listing screen with search bar and paginated results.
///
/// Uses `ClubListViewModel` for state and `PaginatedList` for infinite scrolling.
///
/// ## Usage
/// ```swift
/// ClubListView(viewModel: clubListViewModel)
/// ```
public struct ClubListView: View {
    @ObservedObject private var viewModel: ClubListViewModel

    @Environment(\.appTheme) private var theme

    @State private var searchText: String = ""

    public init(viewModel: ClubListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            SearchBar(
                text: $searchText,
                placeholder: "Search clubs\u{2026}",
                onDebouncedChange: { text in
                    Task { await viewModel.updateSearchText(text) }
                },
                accessibilityId: "clubList_searchBar"
            )
            .padding(.horizontal, theme.spacing.md)
            .padding(.vertical, theme.spacing.sm)

            PaginatedList(
                dataSource: viewModel,
                emptyIcon: "building.2",
                emptyTitle: "No Clubs Found",
                emptyMessage: "Try adjusting your search terms.",
                rowContent: { club in
                    ClubCardView(club: club, theme: theme)
                        .contentShape(Rectangle())
                        .onTapGesture { viewModel.selectClub(club) }
                        .listRowInsets(EdgeInsets(
                            top: theme.spacing.xs,
                            leading: theme.spacing.md,
                            bottom: theme.spacing.xs,
                            trailing: theme.spacing.md
                        ))
                        .accessibilityIdentifier("clubList_card_\(club.id)")
                }
            )
        }
        .task {
            if viewModel.items.isEmpty {
                await viewModel.refresh()
            }
        }
    }
}

// MARK: - Club Card

struct ClubCardView: View {
    let club: Club
    let theme: any AppThemeProtocol

    var body: some View {
        HStack(spacing: theme.spacing.md) {
            // Club image
            CachedAsyncImage(url: club.imageURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Image(systemName: "building.2.fill")
                    .resizable()
                    .foregroundColor(theme.colors.textTertiary)
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius.sm))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                // Name
                Text(club.name)
                    .font(theme.typography.h4)
                    .foregroundColor(theme.colors.textPrimary)
                    .lineLimit(1)
                    .accessibilityIdentifier("clubCard_name")

                // Address
                HStack(spacing: theme.spacing.xs) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(theme.colors.secondary)
                        .accessibilityHidden(true)
                    Text(club.address)
                        .font(theme.typography.bodySmall)
                        .foregroundColor(theme.colors.textSecondary)
                        .lineLimit(2)
                }
                .accessibilityIdentifier("clubCard_address")

                // Contact summary
                if let summary = contactSummary {
                    HStack(spacing: theme.spacing.xs) {
                        Image(systemName: "info.circle")
                            .foregroundColor(theme.colors.secondary)
                            .accessibilityHidden(true)
                        Text(summary)
                            .font(theme.typography.captionLarge)
                            .foregroundColor(theme.colors.textTertiary)
                            .lineLimit(1)
                    }
                    .accessibilityIdentifier("clubCard_contact")
                }
            }

            Spacer()
        }
        .padding(theme.spacing.md)
        .accessibilityElement(children: .contain)
    }

    private var contactSummary: String? {
        var parts: [String] = []
        if club.phoneNumber != nil { parts.append("Phone") }
        if club.websiteURL != nil { parts.append("Website") }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{00b7} ")
    }
}

#Preview {
    Text("ClubListView requires ClubListViewModel with dependencies")
}
#endif
