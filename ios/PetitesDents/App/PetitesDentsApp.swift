import SwiftData
import SwiftUI

@main
@MainActor
struct PetitesDentsApp: App {
    private let container: ModelContainer

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: LaunchEnvironment.isUITesting(arguments)
        )
        do {
            container = try ModelContainer(
                for: ToothRecord.self, ChildProfile.self,
                configurations: configuration
            )
            try AppBootstrap.start(container: container, arguments: arguments)
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
