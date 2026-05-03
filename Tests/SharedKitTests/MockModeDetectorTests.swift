import Foundation
import Testing
@testable import SharedKit

@Suite("MockModeDetector")
struct MockModeDetectorTests {
    @Test("Exposes the documented launch argument")
    func exposesDocumentedArgument() {
        #expect(MockModeDetector.mockModeArgument == "-UITestMockMode")
    }

    @Test("isMockMode reflects ProcessInfo.processInfo.arguments")
    func isMockModeReflectsProcessArguments() {
        // We can't mutate the running process's launch arguments at test time,
        // but we can verify the property reads from ProcessInfo by checking
        // it returns the same answer the source-of-truth check would.
        let actual = ProcessInfo.processInfo.arguments.contains("-UITestMockMode")
        #expect(MockModeDetector.isMockMode == actual)
    }
}
