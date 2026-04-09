import SwiftUI

#if canImport(UIKit)
/// A reusable comedian detail screen showing profile, social links, show history, and favorite button.
///
/// Uses `ComedianDetailViewModel` for state management.
///
/// ## Usage
/// ```swift
/// ComedianDetailView(viewModel: comedianDetailViewModel)
/// ```
public struct ComedianDetailView: View {
    @ObservedObject private var viewModel: ComedianDetailViewModel

    @Environment(\.appTheme) private var theme

    public init(viewModel: ComedianDetailViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            if viewModel.isLoading && viewModel.detail == nil {
                LoadingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.detail == nil {
                ErrorView(error: error) {
                    Task { await viewModel.load() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let detail = viewModel.detail {
                detailContent(detail)
            }
        }
        .task {
            if viewModel.detail == nil {
                await viewModel.load()
            }
        }
    }

    // MARK: - Detail Content

    private func detailContent(_ detail: ComedianDetail) -> some View {
        ScrollView {
            VStack(spacing: theme.spacing.lg) {
                profileHeader(detail.comedian)
                socialLinksSection(detail.comedian.socialLinks)
                showHistorySection(detail.upcomingShows)
            }
            .padding(theme.spacing.md)
        }
        .refreshable {
            await viewModel.load()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await viewModel.toggleFavorite() }
                } label: {
                    Image(systemName: viewModel.isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(viewModel.isFavorite ? theme.colors.error : theme.colors.textSecondary)
                }
                .accessibilityLabel(viewModel.isFavorite ? "Remove from favorites" : "Add to favorites")
                .accessibilityIdentifier("comedianDetail_favoriteButton")
            }
        }
    }

    // MARK: - Profile Header

    private func profileHeader(_ comedian: Comedian) -> some View {
        VStack(spacing: theme.spacing.md) {
            CachedAsyncImage(url: comedian.imageURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(theme.colors.textTertiary)
            }
            .frame(width: 120, height: 120)
            .clipShape(Circle())
            .accessibilityHidden(true)

            Text(comedian.name)
                .font(theme.typography.h2)
                .foregroundColor(theme.colors.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("comedianDetail_name")

            Text("\(comedian.showCount) show\(comedian.showCount == 1 ? "" : "s")")
                .font(theme.typography.bodyMedium)
                .foregroundColor(theme.colors.textSecondary)
                .accessibilityIdentifier("comedianDetail_showCount")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacing.md)
    }

    // MARK: - Social Links

    private func socialLinksSection(_ links: ComedianSocialLinks) -> some View {
        let rows = socialRows(links)
        return Group {
            if !rows.isEmpty {
                VStack(alignment: .leading, spacing: theme.spacing.sm) {
                    Text("Social")
                        .font(theme.typography.h4)
                        .foregroundColor(theme.colors.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    ForEach(rows, id: \.label) { row in
                        socialRow(row)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("comedianDetail_socialSection")
            }
        }
    }

    private func socialRow(_ row: SocialRow) -> some View {
        HStack(spacing: theme.spacing.sm) {
            Image(systemName: row.icon)
                .foregroundColor(theme.colors.secondary)
                .frame(width: theme.iconSizes.lg)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.label)
                    .font(theme.typography.bodyMedium)
                    .foregroundColor(theme.colors.textPrimary)

                if let detail = row.detail {
                    Text(detail)
                        .font(theme.typography.captionLarge)
                        .foregroundColor(theme.colors.textTertiary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func socialRows(_ links: ComedianSocialLinks) -> [SocialRow] {
        var rows: [SocialRow] = []

        if let account = links.instagramAccount {
            rows.append(SocialRow(
                icon: "camera",
                label: "@\(account)",
                detail: links.instagramFollowers.map { formatFollowers($0) }
            ))
        }
        if let account = links.tiktokAccount {
            rows.append(SocialRow(
                icon: "play.rectangle",
                label: "@\(account)",
                detail: links.tiktokFollowers.map { formatFollowers($0) }
            ))
        }
        if let account = links.youtubeAccount {
            rows.append(SocialRow(
                icon: "play.tv",
                label: account,
                detail: links.youtubeFollowers.map { formatFollowers($0) }
            ))
        }
        if let website = links.website {
            rows.append(SocialRow(icon: "globe", label: website, detail: nil))
        }
        if let linktree = links.linktree {
            rows.append(SocialRow(icon: "link", label: linktree, detail: nil))
        }

        return rows
    }

    private func formatFollowers(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM followers", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK followers", Double(count) / 1_000)
        } else {
            return "\(count) followers"
        }
    }

    // MARK: - Show History

    private func showHistorySection(_ shows: [Show]) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            Text("Upcoming Shows")
                .font(theme.typography.h4)
                .foregroundColor(theme.colors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            if shows.isEmpty {
                Text("No upcoming shows")
                    .font(theme.typography.bodyMedium)
                    .foregroundColor(theme.colors.textTertiary)
                    .padding(.vertical, theme.spacing.md)
            } else {
                ForEach(shows) { show in
                    ShowCardView(show: show, theme: theme)
                        .contentShape(Rectangle())
                        .onTapGesture { viewModel.selectShow(show) }
                        .accessibilityIdentifier("comedianDetail_show_\(show.id)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("comedianDetail_showHistory")
    }
}

// MARK: - Social Row Model

private struct SocialRow {
    let icon: String
    let label: String
    let detail: String?
}

#Preview {
    Text("ComedianDetailView requires ComedianDetailViewModel with dependencies")
}
#endif
