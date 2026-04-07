import Foundation

/// Protocol for app state storage operations
public protocol AppStateStorageProtocol {
    func setValue(_ value: some Encodable, forKey key: String)
    func getValue<T: Decodable>(forKey key: String, as type: T.Type) -> T?
    func removeValue(forKey key: String)
    func hasValue(forKey key: String) -> Bool
}

/// UserDefaults-based implementation for storing app UI state
///
/// Provides a type-safe API for persisting various app state types.
/// Native UserDefaults types (String, Int, Bool, Double, Data) are stored directly;
/// complex Codable types fall back to JSON encoding.
///
/// Thread Safety: Uses a serial DispatchQueue for thread-safe access to storage operations.
public class AppStateStorage: AppStateStorageProtocol {
    private let userDefaults: UserDefaults
    /// Serial queue for thread-safe access to storage operations
    private let queue = DispatchQueue(label: "com.sharedkit.appStateStorage")

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// Store a value for a given key
    /// - Parameters:
    ///   - value: The value to store (must be Encodable)
    ///   - key: The storage key
    public func setValue(_ value: some Encodable, forKey key: String) {
        queue.sync {
            // For simple types that UserDefaults natively supports, store directly
            if let stringValue = value as? String {
                userDefaults.set(stringValue, forKey: key)
            } else if let intValue = value as? Int {
                userDefaults.set(intValue, forKey: key)
            } else if let boolValue = value as? Bool {
                userDefaults.set(boolValue, forKey: key)
            } else if let doubleValue = value as? Double {
                userDefaults.set(doubleValue, forKey: key)
            } else if let dataValue = value as? Data {
                userDefaults.set(dataValue, forKey: key)
            } else {
                // For complex types, encode to JSON
                if let encoded = try? JSONEncoder().encode(value) {
                    userDefaults.set(encoded, forKey: key)
                }
            }
        }
    }

    /// Retrieve a value for a given key
    /// - Parameters:
    ///   - key: The storage key
    ///   - type: The expected type of the value
    /// - Returns: The stored value, or nil if not found or type mismatch
    public func getValue<T: Decodable>(forKey key: String, as type: T.Type) -> T? {
        queue.sync {
            // For simple types that UserDefaults natively supports, read directly
            if type == String.self {
                return userDefaults.string(forKey: key) as? T
            } else if type == Int.self {
                guard userDefaults.object(forKey: key) != nil else { return nil }
                return userDefaults.integer(forKey: key) as? T
            } else if type == Bool.self {
                guard userDefaults.object(forKey: key) != nil else { return nil }
                return userDefaults.bool(forKey: key) as? T
            } else if type == Double.self {
                guard userDefaults.object(forKey: key) != nil else { return nil }
                return userDefaults.double(forKey: key) as? T
            } else if type == Data.self {
                return userDefaults.data(forKey: key) as? T
            } else {
                // For complex types, decode from JSON
                guard let data = userDefaults.data(forKey: key) else {
                    return nil
                }

                return try? JSONDecoder().decode(type, from: data)
            }
        }
    }

    /// Remove a stored value for a given key
    /// - Parameter key: The storage key
    public func removeValue(forKey key: String) {
        queue.sync {
            userDefaults.removeObject(forKey: key)
        }
    }

    /// Check if a value exists for a given key
    /// - Parameter key: The storage key
    /// - Returns: True if a value exists, false otherwise
    public func hasValue(forKey key: String) -> Bool {
        queue.sync {
            userDefaults.object(forKey: key) != nil
        }
    }
}
