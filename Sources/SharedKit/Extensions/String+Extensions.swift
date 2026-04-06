import Foundation

public extension String {
    /// Check if string is not empty (ignoring whitespace)
    var isNotEmpty: Bool {
        !trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Trim whitespace and newlines
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Parse `**bold**` markers into an `AttributedString`
    var markdownAttributed: AttributedString {
        (try? AttributedString(markdown: self)) ?? AttributedString(self)
    }
}
