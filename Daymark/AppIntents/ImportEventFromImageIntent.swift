import AppIntents
import CryptoKit
import UniformTypeIdentifiers

struct ImportEventFromImageIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Event from Image"
    static let description = IntentDescription(
        "Find a date and time in an image and create a one-hour calendar event."
    )
    static var supportedModes: IntentModes { .background }

    private static let usesFoundationModels = false

    @Parameter(
        title: "Image",
        description: "An image containing an event title, date, and time",
        supportedContentTypes: [.image],
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var image: [IntentFile]

    static var parameterSummary: some ParameterSummary {
        Summary("Create an event from \(\.$image)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Date> & ProvidesDialog {
        guard let image = image.first else {
            throw ImportEventFromImageError.unreadableImage
        }

        let imageData: Data
        let lines: [RecognizedTextLine]
        do {
            imageData = try image.fileURL.map { try Data(contentsOf: $0) } ?? image.data
            lines = try await EventImageTextRecognizer().recognize(imageData)
        } catch {
            throw ImportEventFromImageError.unreadableImage
        }

        let selected: ExtractedEventCandidate
        if Self.usesFoundationModels {
            do {
                selected = try await FoundationModelEventExtractor().extract(from: lines)
            } catch FoundationModelEventExtractorError.modelUnavailable {
                throw ImportEventFromImageError.modelUnavailable
            } catch {
                throw ImportEventFromImageError.noDateAndTime
            }
        } else {
            let candidates = EventCandidateExtractor().extract(from: lines)
            guard !candidates.isEmpty else {
                throw ImportEventFromImageError.noDateAndTime
            }
            selected = try await selectedCandidate(from: Array(candidates.prefix(5)))
        }
        let end = selected.start.addingTimeInterval(60 * 60)
        try await requestConfirmation(
            dialog:
                "Create \(selected.title) from \(selected.start.formatted(date: .abbreviated, time: .shortened)) to \(end.formatted(date: .omitted, time: .shortened))?"
        )
        let importID = Self.importID(for: imageData, candidate: selected)

        let event: ImportedEvent
        do {
            event = try await EventKitCalendarProvider().createImportedEvent(
                title: selected.title,
                start: selected.start,
                importID: importID
            )
        } catch EventKitCalendarProviderError.fullAccessRequired {
            throw ImportEventFromImageError.calendarAccessRequired
        } catch EventKitCalendarProviderError.missingDefaultCalendar {
            throw ImportEventFromImageError.missingDefaultCalendar
        } catch {
            throw ImportEventFromImageError.couldNotCreateEvent
        }

        return .result(
            value: event.start,
            dialog: "Created \(event.title) for \(event.start.formatted(date: .abbreviated, time: .shortened))."
        )
    }

    private func selectedCandidate(
        from candidates: [ExtractedEventCandidate]
    ) async throws -> ExtractedEventCandidate {
        guard candidates.count > 1 else { return candidates[0] }

        let options = candidates.map {
            IntentChoiceOption(
                title: "\($0.title), \($0.start.formatted(date: .abbreviated, time: .shortened))"
            )
        }
        let selected = try await requestChoice(
            between: options + [.cancel],
            dialog: "Which event should I add?"
        )
        guard let index = options.firstIndex(of: selected) else {
            throw CancellationError()
        }
        return candidates[index]
    }

    private static func importID(for data: Data, candidate: ExtractedEventCandidate) -> String {
        var source = data
        source.append(contentsOf: candidate.title.utf8)
        source.append(contentsOf: String(candidate.start.timeIntervalSince1970).utf8)
        return SHA256.hash(data: source).map { String(format: "%02x", $0) }.joined()
    }
}

enum ImportEventFromImageError: Error, CustomLocalizedStringResourceConvertible {
    case unreadableImage
    case noDateAndTime
    case modelUnavailable
    case calendarAccessRequired
    case missingDefaultCalendar
    case couldNotCreateEvent

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .unreadableImage:
            "Daymark couldn't read that image."
        case .noDateAndTime:
            "Daymark couldn't find a date and time in that image."
        case .modelUnavailable:
            "Apple Intelligence isn't available right now."
        case .calendarAccessRequired:
            "Open Daymark and grant full calendar access before creating an event."
        case .missingDefaultCalendar:
            "Set a default writable calendar before creating an event."
        case .couldNotCreateEvent:
            "Daymark couldn't create the calendar event."
        }
    }
}
