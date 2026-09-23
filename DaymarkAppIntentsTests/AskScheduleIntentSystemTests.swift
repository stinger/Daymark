import AppIntentsTesting
import XCTest

@MainActor
final class AskScheduleIntentSystemTests: XCTestCase {
    private let app = XCUIApplication()
    private let definitions = IntentDefinitions(
        bundleIdentifier: "io.snappmobile.demo.Daymark"
    )

    override func setUp() async throws {
        try await super.setUp()
        app.launch()
    }

    func testIntentIsDiscoverableAndRunsWithRequest() async throws {
        let request = "What is on my schedule today?"
        let intent = definitions.intents["AskScheduleIntent"].makeIntent(
            request: request
        )

        let resolvedRequest: String = try intent.request
        XCTAssertEqual(resolvedRequest, request)

        _ = try await intent.run()
    }
}
