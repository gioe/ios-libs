import Foundation
@testable import SharedKit
import Testing

@Suite("BaseViewModel")
struct BaseViewModelTests {
    // MARK: - Initial State

    @Test("initial state has no loading, no error, no retry")
    func initialState() {
        let vm = BaseViewModel()
        #expect(!vm.isLoading)
        #expect(vm.error == nil)
        #expect(!vm.canRetry)
        #expect(!vm.isRefreshing)
    }

    // MARK: - setLoading

    @Test("setLoading updates isLoading")
    func setLoading() {
        let vm = BaseViewModel()
        vm.setLoading(true)
        #expect(vm.isLoading)
        vm.setLoading(false)
        #expect(!vm.isLoading)
    }

    @Test("setLoading with same value is a no-op")
    func setLoadingSameValue() {
        let vm = BaseViewModel()
        vm.setLoading(false) // already false
        #expect(!vm.isLoading)
    }

    // MARK: - handleError

    @Test("handleError sets error and clears loading")
    func handleErrorSetsError() {
        let vm = BaseViewModel()
        vm.setLoading(true)
        let error = NSError(domain: "test", code: 1)
        vm.handleError(error, context: "test")
        #expect(vm.error != nil)
        #expect(!vm.isLoading)
    }

    @Test("handleError ignores CancellationError")
    func handleErrorIgnoresCancellation() {
        let vm = BaseViewModel()
        vm.handleError(CancellationError(), context: "test")
        #expect(vm.error == nil)
    }

    @Test("handleError ignores NSURLErrorCancelled")
    func handleErrorIgnoresURLCancelled() {
        let vm = BaseViewModel()
        let urlCancelError = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)
        vm.handleError(urlCancelError, context: "test")
        #expect(vm.error == nil)
    }

    @Test("handleError calls ErrorRecorder")
    func handleErrorCallsRecorder() {
        let recorder = MockErrorRecorder()
        let vm = BaseViewModel(errorRecorder: recorder)
        let error = NSError(domain: "test", code: 42)
        vm.handleError(error, context: "my_context")
        #expect(recorder.recordedContext == "my_context")
        #expect(recorder.recordedError != nil)
    }

    @Test("handleError sets canRetry for RetryableError")
    func handleErrorRetryable() {
        let vm = BaseViewModel()
        let retryable = MockRetryableError(isRetryable: true)
        vm.handleError(retryable, context: "test")
        #expect(vm.canRetry)
    }

    @Test("handleError clears canRetry for non-retryable error")
    func handleErrorNonRetryable() {
        let vm = BaseViewModel()
        let nonRetryable = MockRetryableError(isRetryable: false)
        vm.handleError(nonRetryable, context: "test")
        #expect(!vm.canRetry)
    }

    @Test("handleError with regular error sets canRetry to false")
    func handleErrorRegularError() {
        let vm = BaseViewModel()
        // First set canRetry via retryable error
        vm.handleError(MockRetryableError(isRetryable: true), context: "test")
        #expect(vm.canRetry)
        // Then handle a regular error
        vm.handleError(NSError(domain: "test", code: 1), context: "test")
        #expect(!vm.canRetry)
    }

    // MARK: - clearError

    @Test("clearError resets error and canRetry")
    func clearError() {
        let vm = BaseViewModel()
        vm.handleError(MockRetryableError(isRetryable: true), context: "test")
        #expect(vm.error != nil)
        #expect(vm.canRetry)

        vm.clearError()
        #expect(vm.error == nil)
        #expect(!vm.canRetry)
    }

    @Test("clearError on clean state is safe")
    func clearErrorWhenClean() {
        let vm = BaseViewModel()
        vm.clearError()
        #expect(vm.error == nil)
    }

    // MARK: - retry

    @Test("retry executes the stored failed operation")
    func retryExecutesOperation() async {
        let vm = BaseViewModel()
        var retried = false
        vm.handleError(
            NSError(domain: "test", code: 1),
            context: "test",
            retryOperation: { retried = true }
        )
        await vm.retry()
        #expect(retried)
    }

    @Test("retry sets loading and clears error before executing")
    func retryManagesState() async {
        let vm = BaseViewModel()
        var wasLoadingDuringRetry = false
        var errorWasNilDuringRetry = false

        vm.handleError(
            NSError(domain: "test", code: 1),
            context: "test",
            retryOperation: {
                wasLoadingDuringRetry = vm.isLoading
                errorWasNilDuringRetry = (vm.error == nil)
            }
        )
        await vm.retry()
        #expect(wasLoadingDuringRetry)
        #expect(errorWasNilDuringRetry)
    }

    @Test("retry with no stored operation does nothing")
    func retryNoOp() async {
        let vm = BaseViewModel()
        await vm.retry()
        #expect(!vm.isLoading)
    }

    // MARK: - withRefreshing

    @Test("withRefreshing executes operation and resets flag")
    func withRefreshing() async {
        let vm = BaseViewModel()
        var executed = false
        await vm.withRefreshing {
            executed = true
            #expect(vm.isRefreshing)
        }
        #expect(executed)
        #expect(!vm.isRefreshing)
    }

    @Test("withRefreshing guards against concurrent refreshes")
    func withRefreshingGuardsConcurrent() async {
        let vm = BaseViewModel()
        vm.isRefreshing = true
        var executed = false
        await vm.withRefreshing {
            executed = true
        }
        #expect(!executed)
    }

    @Test("withRefreshing handles thrown error via handleError")
    func withRefreshingHandlesError() async {
        let vm = BaseViewModel()
        await vm.withRefreshing {
            throw NSError(domain: "test", code: 1)
        }
        #expect(vm.error != nil)
        #expect(!vm.isRefreshing)
    }

    // MARK: - Validation Helpers

    @Test("validationError returns nil for empty value")
    func validationErrorEmptyValue() {
        let vm = BaseViewModel()
        let result = vm.validationError(for: "", using: Validators.validateEmail)
        #expect(result == nil)
    }

    @Test("validationError returns nil for valid value")
    func validationErrorValidValue() {
        let vm = BaseViewModel()
        let result = vm.validationError(for: "user@example.com", using: Validators.validateEmail)
        #expect(result == nil)
    }

    @Test("validationError returns message for invalid value")
    func validationErrorInvalidValue() {
        let vm = BaseViewModel()
        let result = vm.validationError(for: "invalid", using: Validators.validateEmail)
        #expect(result != nil)
    }

    @Test("validationError matching returns nil for empty confirmation")
    func validationErrorMatchingEmpty() {
        let vm = BaseViewModel()
        let result = vm.validationError(
            for: "",
            matching: "password",
            using: Validators.validatePasswordConfirmation
        )
        #expect(result == nil)
    }

    @Test("validationError matching returns nil when passwords match")
    func validationErrorMatchingValid() {
        let vm = BaseViewModel()
        let result = vm.validationError(
            for: "password",
            matching: "password",
            using: Validators.validatePasswordConfirmation
        )
        #expect(result == nil)
    }

    @Test("validationError matching returns message when passwords differ")
    func validationErrorMatchingInvalid() {
        let vm = BaseViewModel()
        let result = vm.validationError(
            for: "different",
            matching: "password",
            using: Validators.validatePasswordConfirmation
        )
        #expect(result == "Passwords do not match")
    }
}

// MARK: - Test Helpers

private final class MockErrorRecorder: ErrorRecorder {
    var recordedContext: String?
    var recordedError: Error?

    func recordError(_ error: Error, context: String) {
        recordedError = error
        recordedContext = context
    }
}

private struct MockRetryableError: RetryableError {
    let isRetryable: Bool
    var errorDescription: String? { "Mock retryable error" }
}
