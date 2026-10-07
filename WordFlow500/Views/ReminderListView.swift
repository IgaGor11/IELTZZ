import SwiftUI
import UIKit

@MainActor
struct ReminderListView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    let store: ReminderStore
    let lists: [VocabularyList]

    @State private var presentedEditor: ReminderEditorDestination?

    init(
        store: ReminderStore,
        lists: [VocabularyList] = VocabularyList.builtIn
    ) {
        self.store = store
        self.lists = lists
    }

    var body: some View {
        List {
            authorizationSection
            remindersSection
        }
        .navigationTitle("Напоминания")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    presentedEditor = .add
                } label: {
                    Label("Добавить напоминание", systemImage: "plus")
                }
                .disabled(store.isWorking)
                .accessibilityIdentifier("addReminderButton")
            }
        }
        .sheet(item: $presentedEditor) { destination in
            NavigationStack {
                ReminderEditorView(
                    store: store,
                    reminder: destination.reminder,
                    lists: lists
                )
            }
            .presentationDetents([.large])
        }
        .task {
            _ = await store.normalizeListReferences(
                validListIDs: Set(lists.map(\.id))
            )
            await store.refresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await store.refresh()
            }
        }
    }

    private var authorizationSection: some View {
        Section {
            Label(
                store.authorizationStatus.title,
                systemImage: store.authorizationStatus.systemImage
            )
            .foregroundStyle(
                store.authorizationStatus == .denied
                    ? AppTheme.error
                    : Color.primary
            )

            if store.authorizationStatus == .denied {
                Button {
                    openNotificationSettings()
                } label: {
                    Label(
                        "Открыть настройки iOS",
                        systemImage: "gear"
                    )
                }
            } else if store.authorizationStatus == .notDetermined {
                Text("Системный запрос появится только при включении первого напоминания.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if store.scheduledRequestCount > 0 {
                Text(
                    "Активных запусков в неделю: \(store.scheduledRequestCount)"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            if let message = store.lastErrorMessage {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppTheme.error)
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.error)
                    Spacer(minLength: 0)
                    Button {
                        store.clearError()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Скрыть сообщение")
                }
            }
        } header: {
            Text("Статус")
        } footer: {
            Text("Каждое расписание хранится отдельно для текущего профиля.")
        }
    }

    private var remindersSection: some View {
        Section("Расписания") {
            if store.reminders.isEmpty {
                Button {
                    presentedEditor = .add
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "bell.badge")
                            .font(.title2)
                            .foregroundStyle(AppTheme.tint)
                        Text("Добавить первое напоминание")
                            .font(.headline)
                        Text("Выберите время, дни недели и нужный набор слов.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                }
                .buttonStyle(.plain)
            } else {
                ForEach(store.reminders) { reminder in
                    reminderRow(reminder)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task {
                                    await store.delete(
                                        reminderID: reminder.id
                                    )
                                }
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }

                            Button {
                                presentedEditor = .edit(reminder)
                            } label: {
                                Label("Изменить", systemImage: "pencil")
                            }
                            .tint(AppTheme.tint)
                        }
                }
                .onDelete(perform: delete)
            }
        }
    }

    private func reminderRow(_ reminder: StudyReminder) -> some View {
        HStack(spacing: 12) {
            Button {
                presentedEditor = .edit(reminder)
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(reminder.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(timeText(for: reminder))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(AppTheme.tint)
                    }

                    Text(weekdayText(for: reminder.weekdays))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(scopeText(for: reminder))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Toggle(
                "Включить \(reminder.title)",
                isOn: enabledBinding(for: reminder)
            )
            .labelsHidden()
            .disabled(store.isWorking)
        }
        .padding(.vertical, 4)
        .opacity(reminder.enabled ? 1 : 0.72)
        .accessibilityElement(children: .contain)
    }

    private func enabledBinding(
        for reminder: StudyReminder
    ) -> Binding<Bool> {
        Binding {
            store.reminders
                .first(where: { $0.id == reminder.id })?
                .enabled ?? false
        } set: { enabled in
            Task {
                _ = await store.setEnabled(
                    enabled,
                    reminderID: reminder.id
                )
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        let ids = Set(
            offsets.compactMap { index in
                store.reminders.indices.contains(index)
                    ? store.reminders[index].id
                    : nil
            }
        )
        Task {
            await store.delete(reminderIDs: ids)
        }
    }

    private func timeText(for reminder: StudyReminder) -> String {
        String(
            format: "%02d:%02d",
            reminder.hour,
            reminder.minute
        )
    }

    private func weekdayText(for weekdays: Set<Int>) -> String {
        let valid = weekdays.intersection(StudyReminder.validWeekdays)
        if valid == StudyReminder.validWeekdays {
            return "Каждый день"
        }
        if valid == Set(2...6) {
            return "По будням"
        }

        let ordered: [(value: Int, title: String)] = [
            (2, "Пн"), (3, "Вт"), (4, "Ср"), (5, "Чт"),
            (6, "Пт"), (7, "Сб"), (1, "Вс")
        ]
        let titles = ordered.compactMap { day in
            valid.contains(day.value) ? day.title : nil
        }
        return titles.isEmpty ? "Дни не выбраны" : titles.joined(separator: ", ")
    }

    private func scopeText(for reminder: StudyReminder) -> String {
        let listTitle = reminder.effectiveListID.flatMap { selectedID in
            lists.first { $0.id == selectedID }?.name
        }
        var parts = [
            listTitle ?? "Все списки",
            "цель \(reminder.targetCount)"
        ]
        if reminder.onlyDifficult {
            parts.append("только сложные")
        }
        return parts.joined(separator: " • ")
    }

    private func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        openURL(url)
    }
}

private enum ReminderEditorDestination: Identifiable {
    case add
    case edit(StudyReminder)

    var id: String {
        switch self {
        case .add:
            "add"
        case .edit(let reminder):
            "edit-\(reminder.id.uuidString)"
        }
    }

    var reminder: StudyReminder? {
        switch self {
        case .add:
            nil
        case .edit(let reminder):
            reminder
        }
    }
}
