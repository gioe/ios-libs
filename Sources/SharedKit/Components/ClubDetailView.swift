import SwiftUI

#if canImport(UIKit)
/// A reusable club detail screen showing address, upcoming shows, phone number, and website link.
///
/// Uses `ClubDetailViewModel` for state management.
///
/// ## Usage
/// ```swift
/// ClubDetailView(viewModel: clubDetailViewModel)
/// ```
public struct ClubDetailView: View {
    @ObservedObject private var viewModel: ClubDetailViewModel

    @Environment(\.appTheme) private var theme

    public init(viewModel: ClubDetailViewModel) {
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

    private func detailContent(_ detail: ClubDetail) -> some View {
        ScrollView {
            VStack(spacing: theme.spacing.lg) {
                clubHeader(detail.club)
                contactSection(detail.club)
                upcomingShowsSection(detail.upcomingShows)
            }
            .padding(theme.spacing.md)
        }
        .refreshable {
            await viewModel.load()
        }
    }

    // MARK: - Club Header

    private func clubHeader(_ club: Club) -> some View {
        VStack(spacing: theme.spacing.md) {
            CachedAsyncImage(url: club.imageURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Image(systemName: "building.2.fill")
                    .resizable()
                    .foregroundColor(theme.colors.textTertiary)
            }
            .frame(width: 120, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius.md))
            .accessibilityHidden(true)

            Text(club.name)
                .font(theme.typography.h2)
                .foregroundColor(theme.colors.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("clubDetail_name")

            HStack(spacing: theme.spacing.xs) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(theme.colors.secondary)
                    .accessibilityHidden(true)
                Text(club.address)
                    .font(theme.typography.bodyMedium)
                    .foregroundColor(theme.colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .accessibilityIdentifier("clubDetail_address")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacing.md)
    }

    // MARK: - Contact Section

    private func contactSection(_ club: Club) -> some View {
        let rows = contactRows(club)
        return Group {
            if !rows.isEmpty {
                VStack(alignment: .leading, spacing: theme.spacing.sm) {
                    Text("Contact")
                        .font(theme.typography.h4)
                        .foregroundColor(theme.colors.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    ForEach(rows, id: \.label) { row in
                        contactRow(row)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("clubDetail_contactSection")
            }
        }
    }

    private func contactRow(_ row: ContactRow) -> some View {
        HStack(spacing: theme.spacing.sm) {
            Image(systemName: row.icon)
                .foregroundColor(theme.colors.secondary)
                .frame(width: theme.iconSizes.lg)
                .accessibilityHidden(true)

            if let url = row.url {
                Link(row.label, destination: url)
                    .font(theme.typography.bodyMedium)
                    .foregroundColor(theme.colors.primary)
            } else {
                Text(row.label)
                    .font(theme.typography.bodyMedium)
                    .foregroundColor(theme.colors.textPrimary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func contactRows(_ club: Club) -> [ContactRow] {
        var rows: [ContactRow] = []

        if let phone = club.phoneNumber {
            rows.append(ContactRow(
                icon: "phone.fill",
                label: phone,
                url: URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))")
            ))
        }
        if let website = club.websiteURL {
            rows.append(ContactRow(
                icon: "globe",
                label: website.host ?? website.absoluteString,
                url: website
            ))
        }

        return rows
    }

    // MARK: - Upcoming Shows

    private func upcomingShowsSection(_ shows: [Show]) -> some View {
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
                        .accessibilityIdentifier("clubDetail_show_\(show.id)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("clubDetail_upcomingShows")
    }
}

// MARK: - Contact Row Model

private struct ContactRow {
    let icon: String
    let label: String
    let url: URL?
}

#Preview {
    Text("ClubDetailView requires ClubDetailViewModel with dependencies")
}
#endif
