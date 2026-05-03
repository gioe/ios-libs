import Foundation
import Testing
@testable import SharedKit

@Suite("MockModeDetector")
struct MockModeDetectorTests {
    @Test("Exposes the documented launch argument")
    func exposesDocumentedArgument() {
        #expect(MockModeDetector.mockModeArgument == "-UITestMockMode")
    }
}
