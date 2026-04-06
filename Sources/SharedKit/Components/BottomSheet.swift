import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Defines the height at which a bottom sheet can rest.
///
/// Use `fraction` to express the detent as a proportion of the screen height,
/// or `height` for an absolute point value.
public enum BottomSheetDetent: Hashable, Equatable {
    /// A fraction of the available screen height (0.0 ... 1.0).
    case fraction(CGFloat)
    /// An absolute height in points.
    case height(CGFloat)

    /// Resolves the detent to a concrete point value given the available height.
    func resolvedHeight(in availableHeight: CGFloat) -> CGFloat {
        switch self {
        case .fraction(let fraction):
            return availableHeight * min(max(fraction, 0), 1)
        case .height(let height):
            return min(max(height, 0), availableHeight)
        }
    }
}

/// A custom bottom sheet overlay that snaps to configurable detents.
///
/// `BottomSheet` is presented as a ZStack overlay with a semi-transparent scrim.
/// It supports drag-to-dismiss, multiple snap points, and keyboard avoidance.
///
/// ```swift
/// .bottomSheet(isPresented: $showSheet) {
///     Text("Sheet content")
/// }
/// ```
public struct BottomSheet<Content: View>: View {
    @Binding private var isPresented: Bool
    private let detents: [BottomSheetDetent]
    private var selectedDetent: Binding<BottomSheetDetent>?
    private let showsDragIndicator: Bool
    private let dismissOnScrimTap: Bool
    private let onDismiss: (() -> Void)?
    private let content: () -> Content

    @Environment(\.appTheme) private var theme
    @State private var dragOffset: CGFloat = 0
    @State private var keyboardHeight: CGFloat = 0
    @State private var currentDetent: BottomSheetDetent

    /// The threshold in points the user must drag below the smallest detent to dismiss.
    private let dismissThreshold: CGFloat = 50

    /// Creates a `BottomSheet` with the provided configuration.
    ///
    /// - Parameters:
    ///   - isPresented: Binding that controls whether the sheet is visible.
    ///   - detents: The snap points available for the sheet. Defaults to half and full screen.
    ///   - selectedDetent: Optional binding to the currently active detent.
    ///   - showsDragIndicator: Whether to render the drag indicator pill. Defaults to `true`.
    ///   - dismissOnScrimTap: Whether tapping the scrim dismisses the sheet. Defaults to `true`.
    ///   - onDismiss: Closure invoked when the sheet is dismissed.
    ///   - content: The content displayed inside the sheet.
    public init(
        isPresented: Binding<Bool>,
        detents: [BottomSheetDetent] = [.fraction(0.5), .fraction(1.0)],
        selectedDetent: Binding<BottomSheetDetent>? = nil,
        showsDragIndicator: Bool = true,
        dismissOnScrimTap: Bool = true,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._isPresented = isPresented
        self.detents = detents.isEmpty ? [.fraction(0.5)] : detents
        self.selectedDetent = selectedDetent
        self.showsDragIndicator = showsDragIndicator
        self.dismissOnScrimTap = dismissOnScrimTap
        self.onDismiss = onDismiss
        self.content = content
        self._currentDetent = State(initialValue: selectedDetent?.wrappedValue ?? detents.first ?? .fraction(0.5))
    }

    public var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let sheetHeight = currentDetent.resolvedHeight(in: screenHeight)

            ZStack(alignment: .bottom) {
                // Scrim
                if isPresented {
                    theme.colors.scrim
                        .ignoresSafeArea()
                        .onTapGesture {
                            if dismissOnScrimTap {
                                dismiss()
                            }
                        }
                        .transition(.opacity)
                        .accessibilityLabel("Close sheet")
                        .accessibilityHint("Double tap to dismiss the bottom sheet")
                        .accessibilityIdentifier("bottomSheet.scrim")
                }

                // Sheet
                if isPresented {
                    VStack(spacing: 0) {
                        // Drag indicator
                        if showsDragIndicator {
                            dragIndicator
                                .padding(.top, theme.spacing.sm)
                                .padding(.bottom, theme.spacing.xs)
                        }

                        // Content
                        content()
                            .padding(.bottom, keyboardHeight > 0 ? keyboardHeight : 0)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: max(sheetHeight - dragOffset, 0), alignment: .top)
                    .background(
                        TopRoundedRectangle(radius: theme.cornerRadius.xl)
                            .fill(theme.colors.background)
                            .shadowStyle(theme.shadows.lg)
                    )
                    .clipShape(TopRoundedRectangle(radius: theme.cornerRadius.xl))
                    .gesture(dragGesture(screenHeight: screenHeight))
                    .transition(.move(edge: .bottom))
                    .accessibilityElement(children: .contain)
                    .accessibilityAddTraits(.isModal)
                    .accessibilityIdentifier("bottomSheet.container")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .animation(theme.animations.standard, value: isPresented)
            .animation(theme.animations.standard, value: currentDetent)
        }
        .ignoresSafeArea(.keyboard)
        #if canImport(UIKit)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation(theme.animations.standard) {
                    keyboardHeight = frame.height
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(theme.animations.standard) {
                keyboardHeight = 0
            }
        }
        #endif
        .onChange(of: isPresented) { newValue in
            if newValue {
                currentDetent = selectedDetent?.wrappedValue ?? detents.first ?? .fraction(0.5)
                dragOffset = 0
            }
        }
    }

    // MARK: - Subviews

    private var dragIndicator: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(theme.colors.textTertiary)
            .frame(width: 36, height: 5)
            .accessibilityHidden(true)
    }

    // MARK: - Gestures

    private func dragGesture(screenHeight: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                // Only allow downward dragging (positive translation = downward)
                dragOffset = max(value.translation.height, 0)
            }
            .onEnded { value in
                let currentHeight = currentDetent.resolvedHeight(in: screenHeight)
                let projectedHeight = currentHeight - value.translation.height

                // Sort detents by resolved height
                let sortedDetents = detents.sorted {
                    $0.resolvedHeight(in: screenHeight) < $1.resolvedHeight(in: screenHeight)
                }

                let smallestHeight = sortedDetents.first?.resolvedHeight(in: screenHeight) ?? 0

                // Dismiss if dragged below smallest detent by threshold
                if projectedHeight < smallestHeight - dismissThreshold {
                    dismiss()
                    dragOffset = 0
                    return
                }

                // Find nearest detent
                let nearest = sortedDetents.min(by: {
                    abs($0.resolvedHeight(in: screenHeight) - projectedHeight) <
                    abs($1.resolvedHeight(in: screenHeight) - projectedHeight)
                }) ?? currentDetent

                withAnimation(theme.animations.standard) {
                    currentDetent = nearest
                    selectedDetent?.wrappedValue = nearest
                    dragOffset = 0
                }
            }
    }

    // MARK: - Actions

    private func dismiss() {
        withAnimation(theme.animations.standard) {
            isPresented = false
        }
        onDismiss?()
    }
}

// MARK: - View Modifier

private struct BottomSheetModifier<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let detents: [BottomSheetDetent]
    var selectedDetent: Binding<BottomSheetDetent>?
    let showsDragIndicator: Bool
    let dismissOnScrimTap: Bool
    let onDismiss: (() -> Void)?
    @ViewBuilder let sheetContent: () -> SheetContent

    func body(content: Content) -> some View {
        content
            .overlay {
                BottomSheet(
                    isPresented: $isPresented,
                    detents: detents,
                    selectedDetent: selectedDetent,
                    showsDragIndicator: showsDragIndicator,
                    dismissOnScrimTap: dismissOnScrimTap,
                    onDismiss: onDismiss,
                    content: sheetContent
                )
            }
    }
}

extension View {
    /// Presents a custom bottom sheet overlay on this view.
    ///
    /// - Parameters:
    ///   - isPresented: Binding that controls whether the sheet is visible.
    ///   - detents: The snap points available for the sheet. Defaults to half and full screen.
    ///   - selectedDetent: Optional binding to the currently active detent.
    ///   - showsDragIndicator: Whether to render the drag indicator pill. Defaults to `true`.
    ///   - onDismiss: Closure invoked when the sheet is dismissed.
    ///   - content: The content displayed inside the sheet.
    public func bottomSheet<Content: View>(
        isPresented: Binding<Bool>,
        detents: [BottomSheetDetent] = [.fraction(0.5), .fraction(1.0)],
        selectedDetent: Binding<BottomSheetDetent>? = nil,
        showsDragIndicator: Bool = true,
        dismissOnScrimTap: Bool = true,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(BottomSheetModifier(
            isPresented: isPresented,
            detents: detents,
            selectedDetent: selectedDetent,
            showsDragIndicator: showsDragIndicator,
            dismissOnScrimTap: dismissOnScrimTap,
            onDismiss: onDismiss,
            sheetContent: content
        ))
    }
}

// MARK: - Top Rounded Rectangle

/// A rectangle with rounded top corners only, compatible with iOS 16+.
private struct TopRoundedRectangle: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(
            center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(270),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Previews

#Preview("Half Height") {
    BottomSheetPreviewWrapper(initialDetent: .fraction(0.5))
}

#Preview("Full Height") {
    BottomSheetPreviewWrapper(initialDetent: .fraction(1.0))
}

private struct BottomSheetPreviewWrapper: View {
    @State private var isPresented = true
    @State private var selectedDetent: BottomSheetDetent

    init(initialDetent: BottomSheetDetent) {
        _selectedDetent = State(initialValue: initialDetent)
    }

    var body: some View {
        ZStack {
            ColorPalette.background.ignoresSafeArea()

            Button("Show Sheet") {
                isPresented = true
            }

            BottomSheet(
                isPresented: $isPresented,
                detents: [.fraction(0.4), .fraction(0.7), .fraction(1.0)],
                selectedDetent: $selectedDetent
            ) {
                VStack(spacing: 16) {
                    Text("Bottom Sheet")
                        .font(.title2.bold())

                    Text("Drag the handle to snap between detents, or drag down to dismiss.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Spacer()
                }
                .padding()
            }
        }
    }
}
