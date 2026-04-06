import SwiftUI

/// A SwiftUI view that loads a remote image with caching, placeholder, and error states.
///
/// Usage:
/// ```swift
/// CachedAsyncImage(url: avatarURL) { image in
///     image.resizable().scaledToFit()
/// } placeholder: {
///     ProgressView()
/// } error: { _ in
///     Image(systemName: "photo")
/// }
/// ```
public struct CachedAsyncImage<Content: View, Placeholder: View, ErrorContent: View>: View {
    private let url: URL?
    private let cache: ImageCache
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder
    private let errorContent: (Error) -> ErrorContent

    @State private var phase: AsyncImagePhase = .empty

    // MARK: - Init

    /// Creates a cached async image view.
    /// - Parameters:
    ///   - url: The remote image URL. Pass `nil` to show the placeholder.
    ///   - cache: The image cache to use. Defaults to `ImageCache.shared`.
    ///   - content: A closure that transforms the loaded `Image` into a view.
    ///   - placeholder: A view shown while the image is loading or if the URL is nil.
    ///   - error: A view shown when loading fails.
    public init(
        url: URL?,
        cache: ImageCache = .shared,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder error: @escaping (Error) -> ErrorContent
    ) {
        self.url = url
        self.cache = cache
        self.content = content
        self.placeholder = placeholder
        self.errorContent = error
    }

    // MARK: - Body

    public var body: some View {
        Group {
            switch phase {
            case .empty:
                placeholder()
            case .loading:
                placeholder()
            case .loaded(let image):
                content(image)
            case .failed(let err):
                errorContent(err)
            }
        }
        .task(id: url) {
            await load()
        }
    }

    // MARK: - Private

    private func load() async {
        guard let url else { return }

        phase = .loading

        // Check cache first
        if let cached = await cache.image(for: url) {
            phase = .loaded(Image(platformImage: cached))
            return
        }

        // Fetch from network
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let image = PlatformImage(data: data) else {
                throw ImageLoadingError.invalidResponse
            }
            await cache.store(image, for: url)
            phase = .loaded(Image(platformImage: image))
        } catch {
            phase = .failed(error)
        }
    }
}

// MARK: - Convenience Init (no error view)

public extension CachedAsyncImage where ErrorContent == Image {
    /// Creates a cached async image with a default error placeholder (SF Symbol).
    init(
        url: URL?,
        cache: ImageCache = .shared,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.init(
            url: url,
            cache: cache,
            content: content,
            placeholder: placeholder,
            error: { _ in Image(systemName: "photo") }
        )
    }
}

// MARK: - Phase

private enum AsyncImagePhase {
    case empty
    case loading
    case loaded(Image)
    case failed(Error)
}

// MARK: - Error

/// Errors specific to image loading
public enum ImageLoadingError: Error, LocalizedError {
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server returned an invalid response."
        }
    }
}

// MARK: - Platform Image → SwiftUI Image

private extension Image {
    init(platformImage: PlatformImage) {
        #if canImport(UIKit)
        self.init(uiImage: platformImage)
        #elseif canImport(AppKit)
        self.init(nsImage: platformImage)
        #endif
    }
}

// MARK: - Preview

#Preview("Loading") {
    CachedAsyncImage(url: nil) { image in
        image.resizable().scaledToFit()
    } placeholder: {
        ProgressView()
    }
}
