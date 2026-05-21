import Foundation

enum InsightOutputDetail: String, CaseIterable, Identifiable, Sendable {
    case concise
    case balanced
    case detailed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .concise:
            "Concise"
        case .balanced:
            "Balanced"
        case .detailed:
            "Detailed"
        }
    }

    var maximumSectionCount: Int {
        switch self {
        case .concise:
            3
        case .balanced:
            5
        case .detailed:
            7
        }
    }
}

enum InsightOutputTone: String, CaseIterable, Identifiable, Sendable {
    case practical
    case neutral
    case polished

    var id: String { rawValue }

    var title: String {
        switch self {
        case .practical:
            "Practical"
        case .neutral:
            "Neutral"
        case .polished:
            "Polished"
        }
    }
}

struct GenerationPreferences: Sendable {
    enum Keys {
        static let outputDetail = "settings.outputDetail"
        static let outputTone = "settings.outputTone"
        static let enablesMotionEffects = "settings.enablesMotionEffects"
    }

    var outputDetail: InsightOutputDetail
    var outputTone: InsightOutputTone
    var enablesMotionEffects: Bool

    static func current(userDefaults: UserDefaults = .standard) -> GenerationPreferences {
        GenerationPreferences(
            outputDetail: storedOutputDetail(in: userDefaults),
            outputTone: storedOutputTone(in: userDefaults),
            enablesMotionEffects: userDefaults.object(forKey: Keys.enablesMotionEffects) as? Bool ?? true
        )
    }

    private static func storedOutputDetail(in userDefaults: UserDefaults) -> InsightOutputDetail {
        guard let rawValue = userDefaults.string(forKey: Keys.outputDetail),
              let value = InsightOutputDetail(rawValue: rawValue)
        else {
            return .balanced
        }

        return value
    }

    private static func storedOutputTone(in userDefaults: UserDefaults) -> InsightOutputTone {
        guard let rawValue = userDefaults.string(forKey: Keys.outputTone),
              let value = InsightOutputTone(rawValue: rawValue)
        else {
            return .practical
        }

        return value
    }
}
