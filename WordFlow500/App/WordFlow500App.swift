import SwiftUI

@main
@MainActor
struct WordFlow500App: App {
    @Environment(\.scenePhase) private var scenePhase

    @State private var coordinator: AppCoordinator

    init() {
        let defaults = UserDefaults.standard
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-uiTestingReset")
        if isUITesting, let bundleIdentifier = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: bundleIdentifier)
        }
        _coordinator = State(
            initialValue: AppCoordinator(
                defaults: defaults,
                isUITesting: isUITesting
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView(coordinator: coordinator)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase != .active {
                        coordinator.store.save()
                    }
                }
        }
    }
}
