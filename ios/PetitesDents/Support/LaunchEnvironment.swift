import Foundation

/// The launch arguments that switch Petites Dents into a test or capture mode.
/// They are collected here so every gate reads the same spellings.
enum LaunchEnvironment {
    static let uiTesting = "--ui-testing"
    static let screenshots = "--screenshots"
    /// Opens every paid gate. Only honoured together with `--ui-testing`,
    /// which already forces an in-memory store, so it can never be used as a
    /// shortcut on a real library — this repository is public.
    static let storeBypass = "--store-bypass"
    /// Presents the paywall as soon as the app is up. The screenshot pipeline
    /// and the App Review capture of the in-app purchase both depend on it.
    static let paywallScreenshot = "-paywall-screenshot"
    private static let paywallScreenshotLongForm = "--paywall-screenshot"

    static func isUITesting(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        arguments.contains(uiTesting)
    }

    static func isScreenshotRun(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        arguments.contains(screenshots)
    }

    static func isStoreBypassEnabled(
        _ arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        arguments.contains(uiTesting) && arguments.contains(storeBypass)
    }

    static func shouldOpenPaywallAtLaunch(
        _ arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        arguments.contains(paywallScreenshot) || arguments.contains(paywallScreenshotLongForm)
    }
}

/// The single `UserDefaults` the app reads and writes.
///
/// A UI-test or capture run gets a throwaway suite, emptied at launch. Its
/// SwiftData store is already in memory, and its defaults must be just as
/// disposable: `--screenshots` writes `selectedChildID`, which is one of the
/// signals `LegacyEntitlement` reads. Left in the real defaults, it makes the
/// *next* ordinary launch on that device look like an install that predates
/// the Carnet Souvenirs — and hand it the unlock for free. It also made the
/// test suite pass once on a fresh simulator and fail on every rerun.
enum AppDefaults {
    static let suiteName = "com.bnjdpn.petitesdents.uitesting"

    nonisolated(unsafe) static let shared: UserDefaults = make()

    static func make(
        _ arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> UserDefaults {
        guard LaunchEnvironment.isUITesting(arguments),
              let volatile = UserDefaults(suiteName: suiteName) else {
            return .standard
        }

        volatile.removePersistentDomain(forName: suiteName)
        return volatile
    }
}
