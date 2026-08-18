import Foundation

enum ReviewPromptDefaultsKey {
    static let valueEventCount = "reviewPrompt.valueEventCount"
    static let lastPromptedVersion = "reviewPrompt.lastPromptedVersion"
    static let lastPromptDate = "reviewPrompt.lastPromptDate"
}

enum ReviewPromptPolicy {
    static let minimumValueEvents = 2
    static let minimumDaysBetweenPrompts = 14

    static func shouldPrompt(
        valueEventCount: Int,
        currentVersion: String,
        lastPromptedVersion: String?,
        lastPromptDate: Date?,
        now: Date
    ) -> Bool {
        guard valueEventCount >= minimumValueEvents else { return false }
        guard lastPromptedVersion != currentVersion else { return false }
        guard let lastPromptDate else { return true }
        guard let promptAllowedFrom = Calendar(identifier: .gregorian).date(
            byAdding: .day,
            value: minimumDaysBetweenPrompts,
            to: lastPromptDate
        ) else { return false }
        return now >= promptAllowedFrom
    }
}

enum ReviewPromptTracker {
    /// Records one saved tooth milestone (teething or eruption date) and
    /// reports whether the standard system review prompt may be requested now.
    /// When it returns true the prompt is recorded immediately, so callers can
    /// request the review without a second bookkeeping call.
    static func registerValueEvent(
        defaults: UserDefaults = .standard,
        currentVersion: String = ReviewPromptTracker.currentAppVersion,
        now: Date = .now
    ) -> Bool {
        let count = defaults.integer(forKey: ReviewPromptDefaultsKey.valueEventCount) + 1
        defaults.set(count, forKey: ReviewPromptDefaultsKey.valueEventCount)
        let shouldPrompt = ReviewPromptPolicy.shouldPrompt(
            valueEventCount: count,
            currentVersion: currentVersion,
            lastPromptedVersion: defaults.string(forKey: ReviewPromptDefaultsKey.lastPromptedVersion),
            lastPromptDate: defaults.object(forKey: ReviewPromptDefaultsKey.lastPromptDate) as? Date,
            now: now
        )
        if shouldPrompt {
            defaults.set(currentVersion, forKey: ReviewPromptDefaultsKey.lastPromptedVersion)
            defaults.set(now, forKey: ReviewPromptDefaultsKey.lastPromptDate)
        }
        return shouldPrompt
    }

    static var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }
}
