import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var outputDetail: InsightOutputDetail {
        didSet { userDefaults.set(outputDetail.rawValue, forKey: GenerationPreferences.Keys.outputDetail) }
    }

    @Published var outputTone: InsightOutputTone {
        didSet { userDefaults.set(outputTone.rawValue, forKey: GenerationPreferences.Keys.outputTone) }
    }

    @Published var enablesMotionEffects: Bool {
        didSet { userDefaults.set(enablesMotionEffects, forKey: GenerationPreferences.Keys.enablesMotionEffects) }
    }

    @Published private(set) var isResetting = false
    @Published var errorMessage: String?
    @Published private(set) var actionMessage: String?

    private let cardRepository: any CardRepository
    private let userDefaults: UserDefaults

    init(
        cardRepository: any CardRepository,
        userDefaults: UserDefaults = .standard
    ) {
        self.cardRepository = cardRepository
        self.userDefaults = userDefaults

        let preferences = GenerationPreferences.current(userDefaults: userDefaults)
        outputDetail = preferences.outputDetail
        outputTone = preferences.outputTone
        enablesMotionEffects = preferences.enablesMotionEffects
    }

    func resetSavedInsights() async {
        isResetting = true
        errorMessage = nil
        actionMessage = nil

        do {
            try await cardRepository.reset()
            actionMessage = "Saved insights reset."
        } catch {
            errorMessage = "Unable to reset saved insights."
        }

        isResetting = false
    }

    func clearActionMessage() {
        actionMessage = nil
    }

}
