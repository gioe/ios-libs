import SwiftUI

/// A generic modal overlay that presents arbitrary content in a centered card with a dimmed backdrop.
///
/// `ModalContainer` follows the same visual language as `ConfirmationModal` but accepts any
/// SwiftUI content, making it suitable for forms, detail views, or custom confirmation flows.
///
/// ```swift
/// .modalContainer(isPresented: $showModal) {
///     Text("Hello from the modal!")
/// }
/// ```
public struct ModalContainer<Content: View>: View {
    @Binding private var isPresented: Bool
    private let dismissOnScrimTap: Bool
    private let onDismiss: (() -> Void)?
    private let content: () -> Content

    @Environment(\.appTheme) private var theme

    /// Creates a `ModalContainer` with the provided configuration.
    ///
    /// - Parameters:
    ///   - isPresented: Binding that controls whether the modal is visible.
    ///   - dismissOnScrimTap: Whether tapping the scrim dismisses the modal. Defaults to `true`.
    ///   - onDismiss: Closure invoked when the modal is dismissed.
    ///   - content: The content displayed inside the modal card.
    public init(
        isPresented: Binding<Bool>,
        dismissOnScrimTap: Bool = true,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._isPresented = isPresented
        self.dismissOnScrimTap = dismissOnScrimTap
        self.onDismiss = onDismiss
        self.content = content
    }

    public var body: some View {
        ZStack {
            if isPresented {
                // Scrim
                theme.colors.scrim
                    .ignoresSafeArea()
                    .onTapGesture {
                        if dismissOnScrimTap {
                            dismiss()
                        }
                    }
                    .transition(.opacity)
                    .accessibilityLabel("Close modal")
                    .accessibilityHint("Double tap to dismiss the modal")
                    .accessibilityIdentifier("modalContainer.scrim")

                // Card
                content()
                    .padding(theme.spacing.xxl)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadius.xl)
                            .fill(theme.colors.background)
                            .shadowStyle(theme.shadows.lg)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius.xl))
                    .padding(theme.spacing.xl)
                    .transition(
                        .opacity.combined(with: .scale(scale: 0.9))
                    )
                    .accessibilityElement(children: .contain)
                    .accessibilityAddTraits(.isModal)
                    .accessibilityIdentifier("modalContainer.card")
            }
        }
        .animation(theme.animations.standard, value: isPresented)
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

private struct ModalContainerModifier<ModalContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let dismissOnScrimTap: Bool
    let onDismiss: (() -> Void)?
    @ViewBuilder let modalContent: () -> ModalContent

    func body(content: Content) -> some View {
        content
            .overlay {
                ModalContainer(
                    isPresented: $isPresented,
                    dismissOnScrimTap: dismissOnScrimTap,
                    onDismiss: onDismiss,
                    content: modalContent
                )
            }
    }
}

extension View {
    /// Presents a generic modal overlay on this view.
    ///
    /// - Parameters:
    ///   - isPresented: Binding that controls whether the modal is visible.
    ///   - dismissOnScrimTap: Whether tapping the scrim dismisses the modal. Defaults to `true`.
    ///   - onDismiss: Closure invoked when the modal is dismissed.
    ///   - content: The content displayed inside the modal card.
    public func modalContainer<Content: View>(
        isPresented: Binding<Bool>,
        dismissOnScrimTap: Bool = true,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(ModalContainerModifier(
            isPresented: isPresented,
            dismissOnScrimTap: dismissOnScrimTap,
            onDismiss: onDismiss,
            modalContent: content
        ))
    }
}

// MARK: - Previews

#Preview("Simple Content") {
    ModalContainerPreviewWrapper()
}

#Preview("Form Content") {
    ModalContainerFormPreviewWrapper()
}

private struct ModalContainerPreviewWrapper: View {
    @State private var isPresented = true

    var body: some View {
        ZStack {
            ColorPalette.background.ignoresSafeArea()

            Button("Show Modal") {
                isPresented = true
            }

            ModalContainer(isPresented: $isPresented) {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)

                    Text("Success!")
                        .font(.title2.bold())

                    Text("Your action was completed successfully.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}

private struct ModalContainerFormPreviewWrapper: View {
    @State private var isPresented = true
    @State private var name = ""

    var body: some View {
        ZStack {
            ColorPalette.background.ignoresSafeArea()

            Button("Show Modal") {
                isPresented = true
            }

            ModalContainer(isPresented: $isPresented) {
                VStack(spacing: 16) {
                    Text("Enter Your Name")
                        .font(.title3.bold())

                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)

                    Button("Submit") {
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}
