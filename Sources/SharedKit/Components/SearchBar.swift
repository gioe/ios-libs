import Combine
import SwiftUI

/// A reusable search bar with configurable debounce interval, cancel button, and clear action.
/// Exposes a debounced text publisher for filtering use cases.
public struct SearchBar: View {
    @Binding public var text: String
    public let placeholder: String
    public let debounceInterval: TimeInterval
    public let onDebouncedChange: ((String) -> Void)?
    public let accessibilityId: String?

    @Environment(\.appTheme) private var theme
    @FocusState private var isFocused: Bool
    @StateObject private var debouncer: SearchDebouncer

    public init(
        text: Binding<String>,
        placeholder: String = "Search",
        debounceInterval: TimeInterval = 0.3,
        onDebouncedChange: ((String) -> Void)? = nil,
        accessibilityId: String? = nil
    ) {
        _text = text
        self.placeholder = placeholder
        self.debounceInterval = debounceInterval
        self.onDebouncedChange = onDebouncedChange
        self.accessibilityId = accessibilityId
        _debouncer = StateObject(wrappedValue: SearchDebouncer(
            debounceInterval: debounceInterval,
            onDebouncedChange: onDebouncedChange
        ))
    }

    public var body: some View {
        HStack(spacing: theme.spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ColorPalette.textSecondary)
                .font(.system(size: theme.iconSizes.sm))
                .accessibilityHidden(true)

            TextField(placeholder, text: $text)
                .focused($isFocused)
                #if canImport(UIKit)
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                #endif
                .autocorrectionDisabled()
                .accessibilityLabel(placeholder)
                .accessibilityValue(text.isEmpty ? "Empty" : text)
                .accessibilityHint("Type to search")
                .optionalAccessibilityIdentifier(accessibilityId)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ColorPalette.textTertiary)
                        .font(.system(size: theme.iconSizes.sm))
                }
                .accessibilityLabel("Clear search")
                .accessibilityHint("Double tap to clear search text")
            }

            if isFocused {
                Button("Cancel") {
                    text = ""
                    isFocused = false
                    hideKeyboard()
                }
                .font(theme.typography.button)
                .foregroundColor(ColorPalette.primary)
                .accessibilityLabel("Cancel search")
                .accessibilityHint("Double tap to dismiss search")
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, theme.spacing.md)
        .padding(.vertical, theme.spacing.sm)
        .background(ColorPalette.backgroundSecondary)
        .cornerRadius(theme.cornerRadius.md)
        .animation(theme.animations.standard, value: isFocused)
        .animation(theme.animations.standard, value: text.isEmpty)
        .onChange(of: text) { newValue in
            debouncer.send(newValue)
        }
    }
}

// MARK: - Debouncer

private final class SearchDebouncer: ObservableObject {
    private var cancellable: AnyCancellable?
    private let subject = PassthroughSubject<String, Never>()

    init(debounceInterval: TimeInterval, onDebouncedChange: ((String) -> Void)?) {
        guard let onDebouncedChange else { return }
        cancellable = subject
            .debounce(for: .seconds(debounceInterval), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { value in
                onDebouncedChange(value)
            }
    }

    func send(_ value: String) {
        subject.send(value)
    }
}

// MARK: - Previews

#Preview("Empty") {
    SearchBar(text: .constant(""))
        .padding()
}

#Preview("With Text") {
    SearchBar(text: .constant("hello world"))
        .padding()
}

#Preview("Custom Placeholder") {
    SearchBar(
        text: .constant(""),
        placeholder: "Search recipes...",
        debounceInterval: 0.5
    )
    .padding()
}
