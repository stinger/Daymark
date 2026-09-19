import Foundation
import Vision

struct EventImageTextRecognizer: Sendable {
    func recognize(_ data: Data) async throws -> [RecognizedTextLine] {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.automaticallyDetectsLanguage = true
        request.usesLanguageCorrection = true

        return try await request.perform(on: data)
            .sorted { $0.topLeft.y > $1.topLeft.y }
            .compactMap { observation in
                guard let text = observation.topCandidates(1).first else { return nil }
                return RecognizedTextLine(
                    text: text.string,
                    confidence: text.confidence,
                    isTitle: observation.isTitle
                )
            }
    }
}
