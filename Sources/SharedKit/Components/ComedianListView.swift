import SwiftUI

#if canImport(UIKit)
/// A reusable comedian search and listing screen with search bar and paginated results.
///
/// Uses `ComedianListViewModel` for state and `PaginatedList` for infinite scrolling.
///
/// ## Usage
/// ```swift
/// ComedianListView(viewModel: comedianListViewModel)
/// ```
public struct ComedianListView: View {
    @ObservedObject private var viewModel: ComedianListViewModel

    @Environment(\.appTheme) private var theme

    @State private var searchText: String = ""

    public init(viewModel: ComedianListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            SearchBar(
                text: $searchText,
                placeholder: "Search comedians\u{2026}",
                onDebouncedChange: { text in
                    Task { await viewModel.updateSearchText(text) }
                },
                accessibilityId: "comedianList_searchBar"
            )
            .padding(.horizontal, theme.spacing.md)
            .padding(.vertical, theme.spacing.sm)

            PaginatedList(
                dataSource: viewModel,
                emptyIcon: "person.2",
                emptyTitle: "No Comedians Found",
                emptyMessage: "Try adjusting your search terms.",
                rowContent: { comedian in
                    ComedianCardView(comedian: comedian, theme: theme)
                        .contentShape(Rectangle())
                        .onTapGesture { viewModel.selectComedian(comedian) }
                        .listRowInsets(EdgeInsets(
                            top: theme.spacing.xs,
                            leading: theme.spacing.md,
                            bottom: theme.spacing.xs,
                            trailing: theme.spacing.md
                        ))
                        .accessibilityIdentifier("comedianList_card_\(comedian.id)")
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

// MARK: - Comedian Card

struct ComedianCardView: View {
    let comedian: Comedian
    let theme: any AppThemeProtocol

    var body: some View {
        HStack(spacing: theme.spacing.md) {
            // Avatar
            CachedAsyncImage(url: comedian.imageURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(theme.colors.textTertiary)
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                // Name
                Text(comedian.name)
                    .font(theme.typography.h4)
                    .foregroundColor(theme.colors.textPrimary)
                    .lineLimit(1)
                    .accessibilityIdentifier("comedianCard_name")

                // Show count
                HStack(spacing: theme.spacing.xs) {
                    Image(systemName: "theatermasks")
                        .foregroundColor(theme.colors.secondary)
                        .accessibilityHidden(true)
                    Text("\(comedian.showCount) show\(comedian.showCount == 1 ? "" : "s")")
                        .font(theme.typography.bodySmall)
                        .foregroundColor(theme.colors.textSecondary)
                }
                .accessibilityIdentifier("comedianCard_showCount")

                // Social summary
                if let summary = socialSummary {
                    HStack(spacing: theme.spacing.xs) {
                        Image(systemName: "link")
                            .foregroundColor(theme.colors.secondary)
                            .accessibilityHidden(true)
                        Text(summary)
                            .font(theme.typography.captionLarge)
                            .foregroundColor(theme.colors.textTertiary)
                            .lineLimit(1)
                    }
                    .accessibilityIdentifier("comedianCard_social")
                }
            }

            Spacer()

            if comedian.isFavorite {
                Image(systemName: "heart.fill")
                    .foregroundColor(theme.colors.error)
                    .accessibilityLabel("Favorite")
            }
        }
        .padding(theme.spacing.md)
        .accessibilityElement(children: .contain)
    }

    private var socialSummary: String? {
        let links = comedian.socialLinks
        var parts: [String] = []
        if links.instagramAccount != nil { parts.append("Instagram") }
        if links.tiktokAccount != nil { parts.append("TikTok") }
        if links.youtubeAccount != nil { parts.append("YouTube") }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{00b7} ")
    }
}

#Preview {
    Text("ComedianListView requires ComedianListViewModel with dependencies")
}
#endif
