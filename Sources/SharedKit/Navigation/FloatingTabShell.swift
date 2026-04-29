import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Layout settings for ``FloatingTabShell``.
public struct FloatingTabShellLayout: Sendable {
    public let headerAlignment: Alignment
    public let headerHorizontalPadding: CGFloat
    public let headerTopSpacing: CGFloat
    public let showsHeaderWhenNavigating: Bool

    public init(
        headerAlignment: Alignment = .topLeading,
        headerHorizontalPadding: CGFloat = 16,
        headerTopSpacing: CGFloat = 4,
        showsHeaderWhenNavigating: Bool = false
    ) {
        self.headerAlignment = headerAlignment
        self.headerHorizontalPadding = headerHorizontalPadding
        self.headerTopSpacing = headerTopSpacing
        self.showsHeaderWhenNavigating = showsHeaderWhenNavigating
    }

    public func headerTopPadding(safeAreaTop: CGFloat) -> CGFloat {
        safeAreaTop + headerTopSpacing
    }
}

/// Runtime layout information passed to a ``FloatingTabShell`` header.
public struct FloatingTabShellHeaderContext: Sendable {
    public let safeAreaTopInset: CGFloat
    public let isAtRoot: Bool
    public let topPadding: CGFloat

    public init(
        safeAreaTopInset: CGFloat,
        isAtRoot: Bool,
        topPadding: CGFloat
    ) {
        self.safeAreaTopInset = safeAreaTopInset
        self.isAtRoot = isAtRoot
        self.topPadding = topPadding
    }
}

/// A reusable app shell that combines a root ``TabView``, coordinated stack
/// navigation, and a floating safe-area-aware header above the navigation stack.
///
/// Use this when an app has persistent top-level tabs plus shell-level controls
/// such as an account button, content primitive filters, or compact mode pickers.
/// The floating header is rendered outside the `NavigationStack`, so it remains
/// visually above tab and navigation content while avoiding detail routes by
/// default.
public struct FloatingTabShell<
    Route: Hashable,
    Tab: Hashable,
    Destination: View,
    TabContent: View,
    TabLabel: View,
    Header: View
>: View {
    @ObservedObject private var coordinator: NavigationCoordinator<Route>
    @Binding private var selectedTab: Tab

    private let tabs: [Tab]
    private let layout: FloatingTabShellLayout
    private let destination: (Route) -> Destination
    private let tabContent: (Tab) -> TabContent
    private let tabLabel: (Tab) -> TabLabel
    private let header: (FloatingTabShellHeaderContext) -> Header

    public init(
        coordinator: NavigationCoordinator<Route>,
        selectedTab: Binding<Tab>,
        tabs: [Tab],
        layout: FloatingTabShellLayout = FloatingTabShellLayout(),
        @ViewBuilder destination: @escaping (Route) -> Destination,
        @ViewBuilder tabContent: @escaping (Tab) -> TabContent,
        @ViewBuilder tabLabel: @escaping (Tab) -> TabLabel,
        @ViewBuilder header: @escaping (FloatingTabShellHeaderContext) -> Header
    ) {
        self.coordinator = coordinator
        _selectedTab = selectedTab
        self.tabs = tabs
        self.layout = layout
        self.destination = destination
        self.tabContent = tabContent
        self.tabLabel = tabLabel
        self.header = header
    }

    public var body: some View {
        CoordinatedNavigationStack(coordinator: coordinator, destination: destination) {
            TabView(selection: $selectedTab) {
                ForEach(tabs, id: \.self) { tab in
                    tabContent(tab)
                        .tabItem { tabLabel(tab) }
                        .tag(tab)
                }
            }
        }
        .overlay(alignment: layout.headerAlignment) {
            if layout.showsHeaderWhenNavigating || coordinator.path.isEmpty {
                header(headerContext)
                    .padding(.horizontal, layout.headerHorizontalPadding)
                    .padding(.top, headerContext.topPadding)
                    .ignoresSafeArea(.container, edges: .top)
            }
        }
    }

    private var headerContext: FloatingTabShellHeaderContext {
        let safeAreaTopInset = Self.currentTopSafeAreaInset
        return FloatingTabShellHeaderContext(
            safeAreaTopInset: safeAreaTopInset,
            isAtRoot: coordinator.path.isEmpty,
            topPadding: layout.headerTopPadding(safeAreaTop: safeAreaTopInset)
        )
    }

    private static var currentTopSafeAreaInset: CGFloat {
        #if canImport(UIKit)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets.top ?? 0
        #else
        0
        #endif
    }
}
