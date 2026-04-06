import Foundation
import LocalAuthentication
@testable import SharedKit
import Testing

@Suite("BiometricAuthManager")
struct BiometricAuthManagerTests {
    // MARK: - BiometricType

    @Test("BiometricType cases are distinct")
    func biometricTypeCases() {
        #expect(BiometricType.faceID != .touchID)
        #expect(BiometricType.faceID != .none)
        #expect(BiometricType.touchID != .none)
    }

    @Test("BiometricType equality works for same cases")
    func biometricTypeEquality() {
        #expect(BiometricType.faceID == .faceID)
        #expect(BiometricType.touchID == .touchID)
        #expect(BiometricType.none == .none)
    }

    // MARK: - BiometricAuthError Equality

    @Test("BiometricAuthError equality for matching simple cases")
    func errorEqualityMatching() {
        #expect(BiometricAuthError.notAvailable == .notAvailable)
        #expect(BiometricAuthError.notEnrolled == .notEnrolled)
        #expect(BiometricAuthError.lockedOut == .lockedOut)
        #expect(BiometricAuthError.userCancelled == .userCancelled)
        #expect(BiometricAuthError.userFallback == .userFallback)
        #expect(BiometricAuthError.systemCancelled == .systemCancelled)
        #expect(BiometricAuthError.authenticationFailed == .authenticationFailed)
    }

    @Test("BiometricAuthError equality for unknown with same message")
    func errorEqualityUnknownSameMessage() {
        #expect(BiometricAuthError.unknown("test") == .unknown("test"))
    }

    @Test("BiometricAuthError inequality for unknown with different messages")
    func errorInequalityUnknownDifferentMessages() {
        #expect(BiometricAuthError.unknown("a") != .unknown("b"))
    }

    @Test("BiometricAuthError inequality across different cases")
    func errorInequalityCrossCases() {
        #expect(BiometricAuthError.notAvailable != .notEnrolled)
        #expect(BiometricAuthError.lockedOut != .userCancelled)
        #expect(BiometricAuthError.userFallback != .systemCancelled)
        #expect(BiometricAuthError.authenticationFailed != .unknown("failed"))
    }

    // MARK: - BiometricAuthError Descriptions

    @Test("each BiometricAuthError case has a non-nil error description")
    func errorDescriptionsNonNil() {
        let cases: [BiometricAuthError] = [
            .notAvailable, .notEnrolled, .lockedOut,
            .userCancelled, .userFallback, .systemCancelled,
            .authenticationFailed, .unknown("Something went wrong"),
        ]

        for error in cases {
            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.isEmpty == false)
        }
    }

    @Test("unknown error uses its message as description")
    func unknownErrorDescription() {
        let message = "Something unexpected happened"
        let error = BiometricAuthError.unknown(message)
        #expect(error.errorDescription == message)
    }

    @Test("notAvailable description mentions not available")
    func notAvailableDescription() {
        let desc = BiometricAuthError.notAvailable.errorDescription ?? ""
        #expect(desc.contains("not available"))
    }

    @Test("notEnrolled description mentions set up")
    func notEnrolledDescription() {
        let desc = BiometricAuthError.notEnrolled.errorDescription ?? ""
        #expect(desc.contains("not been set up"))
    }

    @Test("lockedOut description mentions locked")
    func lockedOutDescription() {
        let desc = BiometricAuthError.lockedOut.errorDescription ?? ""
        #expect(desc.contains("locked"))
    }

    // MARK: - laErrorMapping Static Dictionary

    @Test("laErrorMapping covers all expected LAError codes")
    func laErrorMappingCoverage() {
        let mapping = BiometricAuthManager.laErrorMapping

        #expect(mapping[.biometryNotAvailable] == .notAvailable)
        #expect(mapping[.biometryNotEnrolled] == .notEnrolled)
        #expect(mapping[.biometryLockout] == .lockedOut)
        #expect(mapping[.userCancel] == .userCancelled)
        #expect(mapping[.userFallback] == .userFallback)
        #expect(mapping[.systemCancel] == .systemCancelled)
        #expect(mapping[.authenticationFailed] == .authenticationFailed)
        #expect(mapping[.appCancel] == .systemCancelled)
        #expect(mapping[.passcodeNotSet] == .notAvailable)
    }

    @Test("laErrorMapping has exactly 9 entries")
    func laErrorMappingCount() {
        #expect(BiometricAuthManager.laErrorMapping.count == 9)
    }

    // MARK: - mapLAError

    @MainActor
    @Test("mapLAError maps LAError codes via the static dictionary")
    func mapLAErrorDictionaryLookup() {
        let manager = BiometricAuthManager()

        for (code, expected) in BiometricAuthManager.laErrorMapping {
            let laError = LAError(code)
            let result = manager.mapLAError(laError)
            #expect(result == expected)
        }
    }

    @MainActor
    @Test("mapLAError returns notAvailable for nil error")
    func mapLAErrorNil() {
        let manager = BiometricAuthManager()
        let result = manager.mapLAError(nil)
        #expect(result == .notAvailable)
    }

    @MainActor
    @Test("mapLAError maps non-LAError NSError to unknown with description")
    func mapLAErrorNSError() {
        let manager = BiometricAuthManager()
        let nsError = NSError(domain: "TestDomain", code: 42, userInfo: [
            NSLocalizedDescriptionKey: "Test error message",
        ])
        let result = manager.mapLAError(nsError)
        #expect(result == .unknown("Test error message"))
    }

    @MainActor
    @Test("mapLAError maps invalidContext to unknown with specific message")
    func mapLAErrorInvalidContext() {
        let manager = BiometricAuthManager()
        let laError = LAError(.invalidContext)
        let result = manager.mapLAError(laError)
        #expect(result == .unknown("Authentication context is invalid"))
    }

    @MainActor
    @Test("mapLAError maps notInteractive to unknown with specific message")
    func mapLAErrorNotInteractive() {
        let manager = BiometricAuthManager()
        let laError = LAError(.notInteractive)
        let result = manager.mapLAError(laError)
        #expect(result == .unknown("Authentication requires user interaction"))
    }

    // MARK: - Manager Initialization

    @MainActor
    @Test("manager initializes with default subsystem")
    func managerInitDefault() {
        let manager = BiometricAuthManager()
        // On CI/macOS without biometrics, these should reflect no-biometric state
        #expect(manager.biometricType == .none || manager.biometricType == .faceID || manager.biometricType == .touchID)
    }

    @MainActor
    @Test("manager initializes with custom subsystem")
    func managerInitCustomSubsystem() {
        let manager = BiometricAuthManager(subsystem: "com.test.biometric")
        // Should not crash and should have valid state
        #expect(manager.biometricType == .none || manager.biometricType == .faceID || manager.biometricType == .touchID)
    }

    @MainActor
    @Test("refreshBiometricStatus updates properties consistently")
    func refreshBiometricStatusConsistency() {
        let manager = BiometricAuthManager()

        manager.refreshBiometricStatus()

        // If biometric is not available, type must be .none
        if !manager.isBiometricAvailable {
            #expect(manager.biometricType == .none)
        }
        // If biometric is available, type must not be .none
        if manager.isBiometricAvailable {
            #expect(manager.biometricType != .none)
        }
    }

    @MainActor
    @Test("manager conforms to BiometricAuthManagerProtocol")
    func protocolConformance() {
        let manager = BiometricAuthManager()
        let proto: any BiometricAuthManagerProtocol = manager
        #expect(proto.biometricType == manager.biometricType)
        #expect(proto.isBiometricAvailable == manager.isBiometricAvailable)
    }

    // MARK: - BiometricAuthError conforms to Error and LocalizedError

    @Test("BiometricAuthError conforms to Error protocol")
    func errorProtocolConformance() {
        let error: any Error = BiometricAuthError.notAvailable
        #expect(error.localizedDescription.isEmpty == false)
    }

    @Test("BiometricAuthError conforms to LocalizedError protocol")
    func localizedErrorConformance() {
        let error: any LocalizedError = BiometricAuthError.lockedOut
        #expect(error.errorDescription != nil)
    }
}
