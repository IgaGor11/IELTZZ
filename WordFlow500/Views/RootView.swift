import SwiftUI

@MainActor
struct RootView: View {
    let coordinator: AppCoordinator

    var body: some View {
        TabView(
            selection: Binding(
                get: { coordinator.selectedTab },
                set: { coordinator.selectedTab = $0 }
            )
        ) {
            NavigationStack {
                StudyView(coordinator: coordinator)
                    .navigationDestination(for: AppRoute.self) {
                        destination(for: $0)
                    }
            }
            .tabItem {
                Label("Учить", systemImage: "rectangle.stack.fill")
            }
            .tag(AppTab.study)
            .accessibilityIdentifier("studyTab")

            NavigationStack {
                WordListView(
                    store: coordinator.store,
                    settings: coordinator.settings,
                    onListsChanged: {
                        coordinator.normalizeSelectedList()
                    }
                )
                .navigationDestination(for: AppRoute.self) {
                    destination(for: $0)
                }
            }
            .tabItem {
                Label("Слова", systemImage: "text.book.closed.fill")
            }
            .tag(AppTab.words)
            .accessibilityIdentifier("wordsTab")

            NavigationStack {
                StatisticsView(store: coordinator.store)
                    .navigationDestination(for: AppRoute.self) {
                        destination(for: $0)
                    }
            }
            .tabItem {
                Label("Статистика", systemImage: "chart.bar.fill")
            }
            .tag(AppTab.statistics)
            .accessibilityIdentifier("statisticsTab")
        }
        .id(coordinator.profileRevision)
        .tint(AppTheme.tint)
        .preferredColorScheme(
            coordinator.settings.isDarkMode ? .dark : .light
        )
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .wordEditor(let id):
            WordEditorView(
                wordID: id,
                store: coordinator.store,
                speech: coordinator.speech
            )
        }
    }
}

#Preview("Главный экран") {
    RootView(
        coordinator: AppCoordinator(defaults: PreviewFixtures.defaults)
    )
}
