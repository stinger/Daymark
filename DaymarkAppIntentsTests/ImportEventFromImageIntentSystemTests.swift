import AppIntents
import AppIntentsTesting
import UniformTypeIdentifiers
import XCTest

@MainActor
final class ImportEventFromImageIntentSystemTests: XCTestCase {
    private let app = XCUIApplication()
    private let definitions = IntentDefinitions(
        bundleIdentifier: "io.snappmobile.demo.Daymark"
    )

    override func setUp() async throws {
        try await super.setUp()
        app.launch()
    }

    func testIntentIsDiscoverableAndAcceptsImageInput() throws {
        let image = IntentFile(
            data: Data([0x89, 0x50, 0x4E, 0x47]),
            filename: "event.png",
            type: .png
        )
        let intent = definitions.intents["ImportEventFromImageIntent"].makeIntent(image: [image])

        let resolvedImages: [IntentFile] = try intent.image
        XCTAssertEqual(resolvedImages.first?.filename, "event.png")
    }
}
