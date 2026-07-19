import SwiftData
import SwiftUI

@main
@MainActor
struct PetitesDentsApp: App {
    private let container: ModelContainer

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: arguments.contains("--ui-testing")
        )
        do {
            container = try ModelContainer(
                for: ToothRecord.self, ChildProfile.self,
                configurations: configuration
            )
            if arguments.contains("--screenshots") {
                try ScreenshotDataService.seed(in: container.mainContext)
            }
            try DateStorageMigration.migrateIfNeeded(in: container.mainContext)
        } catch {
            fatalError("Unable to create the local Petites Dents store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
