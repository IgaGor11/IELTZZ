import SwiftUI
import UIKit

@MainActor
struct ReminderEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let store: ReminderStore
    let lists: [VocabularyList]
    private let isNewReminder: Bool

    @State private var draft: StudyReminder
    @State private var isSaving = false
    @State private var presentedIssue: ReminderEditorIssue?

    init(
        store: ReminderStore,
        reminder: StudyReminder? = nil,
        lists: [VocabularyList] = VocabularyList.builtIn
    ) {
        self.store = store
        self.lists = lists
        isNewReminder = reminder == nil
        var initialDraft = reminder ?? StudyReminder()
        if
            let listID = initialDraft.effectiveListID,
            !lists.contains(where: { $0.id == listID })
        {
            initialDraft.listID = nil
        }
        _draft = State(initialValue: initialDraft)
    }

    var body: some View {
        Form {
            Section("Напоминание") {
                TextField("Название", text: $draft.title)
                    .submitLabel(.done)

                Toggle("Включено", isOn: $draft.enabled)
            }

            Section {
                DatePicker(
                    "Время",
                    selection: timeBinding,
                    displayedComponents: .hourAndMinute
                )
                .accessibilityIdentifier("reminderTimePicker")

                weekdayPicker
            } header: {
                Text("Расписание")
            } footer: {
                if draft.weekdays.isEmpty {
                    Text("Выберите хотя бы один день недели.")
                        .foregroundStyle(AppTheme.error)
                } else {
                    Text("Напоминание повторяется в выбранные дни по местному времени.")
                }
            }

            Section("Слова для занятия") {
                Picker("Список", selection: listSelection) {
                    Text("Все списки").tag(0)
                    ForEach(lists) { list in
                        Text(list.name).tag(list.id)
                    }
                }

                Toggle(
                    "Только сложные слова",
                    isOn: $draft.onlyDifficult
                )

                Stepper(
                    "Цель: \(draft.targetCount) \(wordForm)",
                    value: $draft.targetCount,
                    in: 1...5_000
                )
            }
        }
        .navigationTitle(isNewReminder ? "Новое напоминание" : "Напоминание")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .interactiveDismissDisabled(isSaving)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Отмена") {
                    dismiss()
                }
                .disabled(isSaving)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Сохранить") {
                    save()
                }
                .fontWeight(.semibold)
                .disabled(!isValid || isSaving)
            }
        }
        .alert(item: $presentedIssue) { issue in
            switch issue.kind {
            case .authorizationDenied:
                Alert(
                    title: Text("Уведомления запрещены"),
                    message: Text(issue.message),
                    primaryButton: .default(Text("Настройки")) {
                        openNotificationSettings()
                        dismiss()
                    },
                    secondaryButton: .cancel(Text("Оставить выключенным")) {
                        dismiss()
                    }
                )
            case .warning:
                Alert(
                    title: Text("Не удалось включить напоминание"),
                    message: Text(issue.message),
                    dismissButton: .default(Text("Понятно"))
                )
            }
        }
    }

    private var weekdayPicker: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: 6),
                count: 7
            ),
            spacing: 8
        ) {
            ForEach(ReminderWeekday.ordered) { weekday in
                let isSelected = draft.weekdays.contains(weekday.calendarValue)
                Button {
                    if isSelected {
                        draft.weekdays.remove(weekday.calendarValue)
                    } else {
                        draft.weekdays.insert(weekday.calendarValue)
                    }
                } label: {
                    Text(weekday.shortTitle)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .background(
                            isSelected
                                ? AppTheme.tint
                                : Color.secondary.opacity(0.12),
                            in: RoundedRectangle(
                                cornerRadius: 9,
                                style: .continuous
                            )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(weekday.fullTitle)
                .accessibilityValue(isSelected ? "Выбран" : "Не выбран")
            }
        }
        .padding(.vertical, 4)
    }

    private var timeBinding: Binding<Date> {
        Binding {
            let calendar = Calendar.autoupdatingCurrent
            return calendar.date(
                bySettingHour: draft.hour,
                minute: draft.minute,
                second: 0,
                of: Date()
            ) ?? Date()
        } set: { date in
            let components = Calendar.autoupdatingCurrent.dateComponents(
                [.hour, .minute],
                from: date
            )
            draft.hour = components.hour ?? draft.hour
            draft.minute = components.minute ?? draft.minute
        }
    }

    private var listSelection: Binding<Int> {
        Binding {
            draft.effectiveListID ?? 0
        } set: { selectedListID in
            draft.listID = selectedListID == 0 ? nil : selectedListID
        }
    }

    private var isValid: Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.weekdays.isEmpty
    }

    private var wordForm: String {
        let count = draft.targetCount
        if 11...14 ~= count % 100 {
            return "слов"
        }
        switch count % 10 {
        case 1:
            return "слово"
        case 2...4:
            return "слова"
        default:
            return "слов"
        }
    }

    private func save() {
        Task { @MainActor in
            isSaving = true
            let result = await store.save(draft)
            isSaving = false

            switch result {
            case .saved:
                dismiss()
            case .savedDisabled(let status):
                draft.enabled = false
                if status == .denied {
                    presentedIssue = ReminderEditorIssue(
                        kind: .authorizationDenied,
                        message: "Напоминание сохранено выключенным. Разрешите уведомления для приложения в настройках iOS."
                    )
                } else {
                    presentedIssue = ReminderEditorIssue(
                        kind: .warning,
                        message: "Напоминание сохранено выключенным, потому что разрешение не было получено."
                    )
                }
            case .savedWithWarning(let message):
                draft.enabled = store.reminders
                    .first(where: { $0.id == draft.id })?
                    .enabled ?? false
                presentedIssue = ReminderEditorIssue(
                    kind: store.authorizationStatus == .denied
                        ? .authorizationDenied
                        : .warning,
                    message: message
                )
            }
        }
    }

    private func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        openURL(url)
    }
}

private struct ReminderEditorIssue: Identifiable {
    enum Kind {
        case authorizationDenied
        case warning
    }

    let id = UUID()
    let kind: Kind
    let message: String
}

private struct ReminderWeekday: Identifiable {
    let calendarValue: Int
    let shortTitle: String
    let fullTitle: String

    var id: Int { calendarValue }

    static let ordered = [
        ReminderWeekday(
            calendarValue: 2,
            shortTitle: "Пн",
            fullTitle: "Понедельник"
        ),
        ReminderWeekday(
            calendarValue: 3,
            shortTitle: "Вт",
            fullTitle: "Вторник"
        ),
        ReminderWeekday(
            calendarValue: 4,
            shortTitle: "Ср",
            fullTitle: "Среда"
        ),
        ReminderWeekday(
            calendarValue: 5,
            shortTitle: "Чт",
            fullTitle: "Четверг"
        ),
        ReminderWeekday(
            calendarValue: 6,
            shortTitle: "Пт",
            fullTitle: "Пятница"
        ),
        ReminderWeekday(
            calendarValue: 7,
            shortTitle: "Сб",
            fullTitle: "Суббота"
        ),
        ReminderWeekday(
            calendarValue: 1,
            shortTitle: "Вс",
            fullTitle: "Воскресенье"
        )
    ]
}
