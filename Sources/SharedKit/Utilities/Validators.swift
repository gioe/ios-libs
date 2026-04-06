import Foundation

/// Input validation utilities
///
/// This enum provides centralized validation logic for user input across the application.
/// All validation methods return a `ValidationResult` that can be either `.valid` or
/// `.invalid(String)` with a user-friendly error message.
public enum Validators {
    // MARK: - Email Validation

    /// Validate email format
    ///
    /// Email Requirements:
    /// - Must not be empty or whitespace-only
    /// - Must match a valid email pattern (user@domain.tld)
    ///
    /// - Parameter email: The email address to validate
    /// - Returns: `.valid` if email meets all requirements, `.invalid(message)` otherwise
    public static func validateEmail(_ email: String) -> ValidationResult {
        guard email.isNotEmpty else {
            return .invalid("Email is required")
        }

        // Email regex pattern: user@domain.tld
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        guard predicate.evaluate(with: email) else {
            return .invalid("Please enter a valid email address")
        }

        return .valid
    }

    // MARK: - Password Validation

    /// Validate password meets security requirements
    ///
    /// Password Requirements:
    /// - Minimum length (configurable, default 8 characters)
    /// - Must not be empty or whitespace-only
    ///
    /// - Parameters:
    ///   - password: The password to validate
    ///   - minLength: Minimum required password length (default: 8)
    /// - Returns: `.valid` if password meets all requirements, `.invalid(message)` otherwise
    public static func validatePassword(_ password: String, minLength: Int = 8) -> ValidationResult {
        guard password.isNotEmpty else {
            return .invalid("Password is required")
        }
        guard password.count >= minLength else {
            return .invalid("Password must be at least \(minLength) characters")
        }
        return .valid
    }

    // MARK: - Name Validation

    /// Validate name field
    ///
    /// Requirements:
    /// - Name must not be empty or whitespace-only
    /// - Name must meet minimum length requirement (configurable, default 2 characters)
    ///
    /// - Parameters:
    ///   - name: The name to validate
    ///   - fieldName: The display name for the field (used in error messages)
    ///   - minLength: Minimum required name length (default: 2)
    /// - Returns: `.valid` if name meets all requirements, `.invalid(message)` otherwise
    public static func validateName(_ name: String, fieldName: String = "Name", minLength: Int = 2) -> ValidationResult {
        guard name.isNotEmpty else {
            return .invalid("\(fieldName) is required")
        }
        guard name.count >= minLength else {
            return .invalid("\(fieldName) must be at least \(minLength) characters")
        }
        return .valid
    }

    /// Validate password using default minimum length (8 characters).
    ///
    /// This single-argument overload exists so `Validators.validatePassword` can be passed
    /// as a `(String) -> ValidationResult` function reference (e.g., to `validationError(for:using:)`).
    /// Default parameters do not satisfy the `(String) -> ValidationResult` type signature.
    public static func validatePassword(_ password: String) -> ValidationResult {
        validatePassword(password, minLength: 8)
    }

    /// Validate name using default minimum length (2 characters).
    ///
    /// This single-argument overload exists so `Validators.validateName` can be passed
    /// as a `(String) -> ValidationResult` function reference.
    public static func validateName(_ name: String) -> ValidationResult {
        validateName(name, fieldName: "Name", minLength: 2)
    }

    // MARK: - Password Confirmation Validation

    /// Validate password confirmation matches original password
    ///
    /// Requirements:
    /// - Confirmation must exactly match the original password
    ///
    /// - Parameters:
    ///   - password: The original password
    ///   - confirmation: The confirmation password
    /// - Returns: `.valid` if passwords match, `.invalid(message)` otherwise
    public static func validatePasswordConfirmation(_ password: String, _ confirmation: String) -> ValidationResult {
        guard password == confirmation else {
            return .invalid("Passwords do not match")
        }
        return .valid
    }

    // MARK: - Minimum Length Validation

    /// Validate that a text field meets a minimum character count
    ///
    /// Requirements:
    /// - Text must not be empty or whitespace-only
    /// - Text must be at least `min` characters
    ///
    /// This generalized validator replaces field-specific validators (e.g., feedback description).
    ///
    /// - Parameters:
    ///   - text: The text to validate
    ///   - fieldName: Display name for the field used in error messages (default: "Description")
    ///   - min: Minimum required character count (default: 10)
    /// - Returns: `.valid` if text meets all requirements, `.invalid(message)` otherwise
    public static func validateMinLength(_ text: String, fieldName: String = "Description", min: Int = 10) -> ValidationResult {
        guard text.isNotEmpty else {
            return .invalid("\(fieldName) is required")
        }
        guard text.count >= min else {
            return .invalid("\(fieldName) must be at least \(min) characters")
        }
        return .valid
    }

    /// Validate minimum-length text using default field name and minimum (10 characters).
    ///
    /// Single-argument overload so `Validators.validateMinLength` can be passed
    /// as a `(String) -> ValidationResult` function reference.
    public static func validateMinLength(_ text: String) -> ValidationResult {
        validateMinLength(text, fieldName: "Description", min: 10)
    }

    // MARK: - Phone Validation

    /// Validate phone number format
    ///
    /// Phone Requirements:
    /// - Must not be empty or whitespace-only
    /// - Must contain only digits, spaces, hyphens, parentheses, or a leading `+`
    /// - Must contain at least 7 digits and no more than 15 (E.164 range)
    ///
    /// - Parameter phone: The phone number string to validate
    /// - Returns: `.valid` if phone meets all requirements, `.invalid(message)` otherwise
    public static func validatePhone(_ phone: String) -> ValidationResult {
        guard phone.isNotEmpty else {
            return .invalid("Phone number is required")
        }

        // Strip allowed formatting characters to count digits
        let allowedFormatting = CharacterSet(charactersIn: " -+()")
        let stripped = phone.unicodeScalars.filter { !allowedFormatting.contains($0) }

        // After stripping formatting, only digits should remain
        guard stripped.allSatisfy(\.properties.isASCIIHexDigit),
              stripped.allSatisfy({ $0.value >= 0x30 && $0.value <= 0x39 }) else {
            return .invalid("Phone number can only contain digits, spaces, hyphens, parentheses, or a leading +")
        }

        let digitCount = stripped.count
        guard digitCount >= 7 else {
            return .invalid("Phone number must contain at least 7 digits")
        }
        guard digitCount <= 15 else {
            return .invalid("Phone number must contain no more than 15 digits")
        }

        return .valid
    }

    // MARK: - URL Validation

    /// Validate URL format
    ///
    /// URL Requirements:
    /// - Must not be empty or whitespace-only
    /// - Must be parseable by `URL(string:)`
    /// - Must have an `http` or `https` scheme
    /// - Must have a non-empty host
    ///
    /// - Parameter urlString: The URL string to validate
    /// - Returns: `.valid` if URL meets all requirements, `.invalid(message)` otherwise
    public static func validateURL(_ urlString: String) -> ValidationResult {
        guard urlString.isNotEmpty else {
            return .invalid("URL is required")
        }

        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              let host = url.host, !host.isEmpty else {
            return .invalid("Please enter a valid URL (e.g. https://example.com)")
        }

        return .valid
    }

    // MARK: - Birth Year Validation

    /// Validate birth year field
    ///
    /// Requirements:
    /// - Year must be a valid integer
    /// - Year must be between `minYear` and current year (inclusive)
    ///
    /// - Parameters:
    ///   - birthYear: The birth year string to validate
    ///   - minYear: The earliest acceptable birth year (default: 1900)
    /// - Returns: `.valid` if birth year meets all requirements, `.invalid(message)` otherwise
    public static func validateBirthYear(_ birthYear: String, minYear: Int = 1900) -> ValidationResult {
        // Empty birth year is valid (optional field)
        let trimmed = birthYear.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return .valid
        }

        // Must be a valid integer
        guard let year = Int(trimmed) else {
            return .invalid("Birth year must be a valid year")
        }

        // Get current year dynamically
        let currentYear = Calendar.current.component(.year, from: Date())

        // Year must be >= minYear
        guard year >= minYear else {
            return .invalid("Birth year must be \(minYear) or later")
        }

        // Year must be <= current year
        guard year <= currentYear else {
            return .invalid("Birth year cannot be in the future")
        }

        return .valid
    }

    /// Validate birth year using default minimum year (1900).
    ///
    /// Single-argument overload so `Validators.validateBirthYear` can be passed
    /// as a `(String) -> ValidationResult` function reference.
    public static func validateBirthYear(_ birthYear: String) -> ValidationResult {
        validateBirthYear(birthYear, minYear: 1900)
    }
}

/// Result of validation
public enum ValidationResult {
    case valid
    case invalid(String)

    public var isValid: Bool {
        if case .valid = self {
            return true
        }
        return false
    }

    public var errorMessage: String? {
        if case let .invalid(message) = self {
            return message
        }
        return nil
    }
}
