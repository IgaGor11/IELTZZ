import SwiftUI

@MainActor
struct SettingsView: View {
    let coordinator: AppCoordinator

    var body: some View {
        NavigationStack {
            SettingsContent(
                coordinator: coordinator,
                settings: coordinator.settings,
                store: coordinator.store
            )
        }
    }
}

@MainActor
private struct SettingsContent: View {
    @Environment(\.dismiss) private var dismiss

    let coordinator: AppCoordinator
    @Bindable var settings: AppSettings
    let store: VocabularyStore

    @State private var showsResetConfirmation = false

    var body: some View {
        Form {
            Section("Обучение") {
                Picker("Режим", selection: $settings.studyMode) {
                    ForEach(StudyMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                VocabularyListPicker(
                    title: "Список",
                    selection: $settings.selectedList,
                    lists: store.lists,
                    includesAll: true
                )
                .accessibilityIdentifier("settingsListPicker")

                Toggle("Только сложные слова", isOn: $settings.onlyDifficult)
            }

            Section {
                Toggle(
                    "Показывать холст для рисования",
                    isOn: $settings.showsDrawingCanvas
                )
                Toggle(
                    "Автоматически показывать ответ",
                    isOn: $settings.automaticallyShowsAnswer
                )
                Toggle(
                    "Автоозвучивание",
                    isOn: $settings.autoplayPronunciation
                )
            } header: {
                Text("Поведение")
            } footer: {
                Text(
                    "После проверки карточка остаётся открытой, пока вы не нажмёте «Следующее слово»."
                )
            }

            Section("Организация") {
                NavigationLink {
                    ProfileManagementView(coordinator: coordinator)
                } label: {
                    LabeledContent {
                        Text(coordinator.activeProfile.name)
                            .foregroundStyle(.secondary)
                    } label: {
                        Label("Профили", systemImage: "person.2.fill")
                    }
                }
                .accessibilityIdentifier("profilesSettingsLink")

                NavigationLink {
                    ListManagementView(store: store) {
                        coordinator.normalizeSelectedList()
                    }
                } label: {
                    Label(
                        "Управление списками",
                        systemImage: "folder.badge.gearshape"
                    )
                }

                NavigationLink {
                    ReminderListView(
                        store: coordinator.reminderStore,
                        lists: store.lists
                    )
                } label: {
                    Label("Напоминания", systemImage: "bell.badge.fill")
                }
                .accessibilityIdentifier("remindersSettingsLink")
            }

            Section {
                Button("Сбросить прогресс", role: .destructive) {
                    showsResetConfirmation = true
                }
            } header: {
                Text("Прогресс")
            } footer: {
                Text(
                    "Уровни, даты, статистика и отметки сложности будут сброшены. Переводы, примеры, списки и рисунки сохранятся."
                )
            }
        }
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Готово") {
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
        .alert("Сбросить прогресс?", isPresented: $showsResetConfirmation) {
            Button("Отмена", role: .cancel) {}
            Button("Сбросить", role: .destructive) {
                store.resetProgress()
            }
        } message: {
            Text(
                "Действие нельзя отменить, но ваши слова, переводы, примеры, списки и рисунки останутся."
            )
        }
        .onAppear {
            settings.normalizeSelectedList(validListIDs: store.validListIDs)
        }
    }
}

#Preview("Настройки") {
    SettingsView(
        coordinator: AppCoordinator(defaults: PreviewFixtures.defaults)
    )
}
