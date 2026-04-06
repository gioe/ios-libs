import Foundation

/// A property wrapper that provides unified persistent storage,
/// routing to UserDefaults for non-sensitive data and Keychain for sensitive data.
///
/// Usage:
/// ```swift
/// // Non-sensitive (UserDefaults)
/// @Stored("onboarding_complete") var hasOnboarded = false
///
/// // Sensitive (Keychain)
/// @Stored("auth_token", secure: true) var token: String?
///
/// // Custom Codable type
/// @Stored("user_prefs") var preferences = UserPreferences()
/// ```
@propertyWrapper
public struct Stored<Value: Codable> {
    private let key: String
    private let defaultValue: Value
    private let backend: StorageBackend

    public var wrappedValue: Value {
        get { backend.get(key: key) ?? defaultValue }
        nonmutating set { backend.set(newValue, key: key) }
    }

    /// Creates a stored property backed by UserDefaults or Keychain.
    /// - Parameters:
    ///   - key: The storage key.
    ///   - defaultValue: The value returned when no stored value exists.
    ///   - secure: When `true`, uses Keychain via `SecureStorageProtocol`. Defaults to `false` (UserDefaults).
    ///   - secureStorage: The secure storage implementation. Defaults to a shared `KeychainStorage`.
    ///   - defaults: The UserDefaults instance for non-secure storage. Defaults to `.standard`.
    public init(
        wrappedValue defaultValue: Value,
        _ key: String,
        secure: Bool = false,
        secureStorage: SecureStorageProtocol = KeychainStorage(),
        defaults: UserDefaults = .standard
    ) {
        self.key = key
        self.defaultValue = defaultValue
        self.backend = secure
            ? .secure(secureStorage)
            : .userDefaults(defaults)
    }
}

// MARK: - Optional support

extension Stored where Value: ExpressibleByNilLiteral {
    /// Convenience initializer for optional values, defaulting to `nil`.
    public init(
        _ key: String,
        secure: Bool = false,
        secureStorage: SecureStorageProtocol = KeychainStorage(),
        defaults: UserDefaults = .standard
    ) {
        self.init(
            wrappedValue: nil,
            key,
            secure: secure,
            secureStorage: secureStorage,
            defaults: defaults
        )
    }
}

// MARK: - Storage Backend

private enum StorageBackend {
    case userDefaults(UserDefaults)
    case secure(SecureStorageProtocol)

    func get<V: Codable>(key: String) -> V? {
        switch self {
        case .userDefaults(let defaults):
            guard let data = defaults.data(forKey: key) else { return nil }
            return try? JSONDecoder().decode(V.self, from: data)

        case .secure(let storage):
            guard let string = try? storage.retrieve(forKey: key),
                  let data = string.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(V.self, from: data)
        }
    }

    func set<V: Codable>(_ value: V, key: String) {
        switch self {
        case .userDefaults(let defaults):
            if let optional = value as? OptionalProtocol, optional.isNil {
                defaults.removeObject(forKey: key)
                return
            }
            guard let data = try? JSONEncoder().encode(value) else { return }
            defaults.set(data, forKey: key)

        case .secure(let storage):
            if let optional = value as? OptionalProtocol, optional.isNil {
                try? storage.delete(forKey: key)
                return
            }
            guard let data = try? JSONEncoder().encode(value),
                  let string = String(data: data, encoding: .utf8) else { return }
            try? storage.save(string, forKey: key)
        }
    }
}

// MARK: - Optional nil detection

private protocol OptionalProtocol {
    var isNil: Bool { get }
}

extension Optional: OptionalProtocol {
    var isNil: Bool { self == nil }
}
