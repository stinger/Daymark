import FoundationModels

extension SystemLanguageModel {
    var daymarkAvailabilityDescription: String {
        switch availability {
        case .available:
            "Foundation Models is ready for on-device requests."
        case .unavailable(.deviceNotEligible):
            "This device does not support Foundation Models. Use an Apple Intelligence-capable iPhone."
        case .unavailable(.appleIntelligenceNotEnabled):
            "Apple Intelligence is disabled. Enable it in Settings before using the assistant."
        case .unavailable(.modelNotReady):
            "The on-device model is not ready. Keep the device connected and try again later."
        case .unavailable:
            "Foundation Models is unavailable. Check Apple Intelligence in Settings."
        }
    }
}
