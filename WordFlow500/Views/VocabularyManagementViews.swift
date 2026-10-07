import SwiftUI

@MainActor
struct AddWordView: View {
    @Environment(\.dismiss) private var dismiss

    let store: VocabularyStore

    @State private var english = ""
    @State private var translation = ""
    @State private var example = ""
    @State private var listID: Int
    @State private var issue: VocabularyIssue?

    init(store: VocabularyStore, initialListID: Int? = nil) {
        self.store = store
        let validInitial = initialListID.flatMap { candidate in
            store.validListIDs.contains(candidate) ? candidate : nil
        }
        _listID = State(
            initialValue: validInitial ?? store.lists.first?.id ?? 1
        )
    }

    var body: some View {
        Form {
            Section("Новое слово") {
                TextField("Английское слово", text: $english)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("newWordEnglishField")

                TextField("Перевод", text: $translation, axis: .vertical)
                    .lineLimit(1...3)

                TextField("Ваш пример", text: $example, axis: .vertical)
                    .lineLimit(2...5)
            }

            Section("Расположение") {
                VocabularyListPicker(
                    title: "Список",
                    selection: $listID,
                    lists: store.lists,
                    includesAll: false
                )
            }
        }
        .navigationTitle("Добавить слово")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Отмена") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Добавить") {
                    addWord()
                }
                .fontWeight(.semibold)
                .disabled(
                    english.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
                )
            }
        }
        .alert(item: $issue) { issue in
            Alert(
                title: Text("Не удалось добавить слово"),
                message: Text(issue.message),
                dismissButton: .default(Text("Понятно"))
            )
        }
    }

    private func addWord() {
        do {
            _ = try store.addWord(
                english,
                translation: translation,
                example: example,
                toList: listID
            )
            dismiss()
        } catch {
            issue = VocabularyIssue(error.localizedDescription)
        }
    }
}

@MainActor
struct BatchImportView: View {
    @Environment(\.dismiss) private var dismiss

    let store: VocabularyStore

    @State private var text = ""
    @State private var listID: Int
    @State private var issue: VocabularyIssue?
    @State private var summary: ImportSummary?

    init(store: VocabularyStore, initialListID: Int? = nil) {
        self.store = store
        let validInitial = initialListID.flatMap { candidate in
            store.validListIDs.contains(candidate) ? candidate : nil
        }
        _listID = State(
            initialValue: validInitial ?? store.lists.first?.id ?? 1
        )
    }

    var body: some View {
        Form {
            Section {
                TextEditor(text: $text)
                    .frame(minHeight: 220)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("batchWordsEditor")
            } header: {
                Text("Вставьте слова")
            } footer: {
                Text(
                    """
                    Одно слово на строку или через запятую. Чтобы сразу добавить данные: word | перевод | пример. Вместо «|» можно использовать табуляцию или «;».
                    """
                )
            }

            Section("Куда добавить") {
                VocabularyListPicker(
                    title: "Список",
                    selection: $listID,
                    lists: store.lists,
                    includesAll: false
                )
            }
        }
        .navigationTitle("Пакетный импорт")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Закрыть") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Импортировать") {
                    importWords()
                }
                .fontWeight(.semibold)
                .disabled(
                    text.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
                )
            }
        }
        .alert(item: $issue) { issue in
            Alert(
                title: Text("Импорт не выполнен"),
                message: Text(issue.message),
                dismissButton: .default(Text("Понятно"))
            )
        }
        .alert(item: $summary) { summary in
            Alert(
                title: Text("Импорт завершён"),
                message: Text(summary.message),
                dismissButton: .default(Text("Готово")) {
                    if summary.addedCount > 0 {
                        dismiss()
                    }
                }
            )
        }
    }

    private func importWords() {
        do {
            let result = try store.importWords(text, toList: listID)
            summary = ImportSummary(result: result)
        } catch {
            issue = VocabularyIssue(error.localizedDescription)
        }
    }
}

@MainActor
struct ListManagementView: View {
    let store: VocabularyStore
    let onListsChanged: () -> Void

    @State private var editor: ListEditorDestination?
    @State private var pendingDeletion: VocabularyList?
    @State private var issue: VocabularyIssue?

    init(
        store: VocabularyStore,
        onListsChanged: @escaping () -> Void = {}
    ) {
        self.store = store
        self.onListsChanged = onListsChanged
    }

    var body: some View {
        List {
            Section {
                ForEach(store.lists) { list in
                    Button {
                        editor = .rename(list)
                    } label: {
                        HStack(spacing: 12) {
                            Image(
                                systemName: list.isBuiltIn
                                    ? "books.vertical.fill"
                                    : "folder.fill"
                            )
                            .foregroundStyle(
                                list.isBuiltIn ? AppTheme.tint : Color.orange
                            )

                            VStack(alignment: .leading, spacing: 3) {
                                Text(list.name)
                                    .foregroundStyle(.primary)
                                Text(
                                    "\(store.words.count { $0.listNumber == list.id }) слов"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        if !list.isBuiltIn {
                            Button(role: .destructive) {
                                pendingDeletion = list
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                    }
                }
            } footer: {
                Text(
                    "Встроенные списки можно переименовать. При удалении пользовательского списка его слова будут перенесены в первый доступный список."
                )
            }
        }
        .navigationTitle("Управление списками")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editor = .add
                } label: {
                    Label("Новый список", systemImage: "plus")
                }
                .accessibilityIdentifier("addListButton")
            }
        }
        .sheet(item: $editor) { destination in
            NavigationStack {
                ListNameEditor(
                    destination: destination,
                    store: store
                ) {
                    onListsChanged()
                }
            }
            .presentationDetents([.medium])
        }
        .confirmationDialog(
            "Удалить «\(pendingDeletion?.name ?? "")»?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Удалить список", role: .destructive) {
                guard let pendingDeletion else { return }
                do {
                    _ = try store.deleteList(id: pendingDeletion.id)
                    onListsChanged()
                    self.pendingDeletion = nil
                } catch {
                    issue = VocabularyIssue(error.localizedDescription)
                }
            }
            Button("Отмена", role: .cancel) {
                pendingDeletion = nil
            }
        } message: {
            Text("Слова не удалятся — приложение перенесёт их в другой список.")
        }
        .alert(item: $issue) { issue in
            Alert(
                title: Text("Не удалось изменить список"),
                message: Text(issue.message),
                dismissButton: .default(Text("Понятно"))
            )
        }
    }
}

struct VocabularyListPicker: View {
    let title: String
    @Binding var selection: Int
    let lists: [VocabularyList]
    let includesAll: Bool

    var body: some View {
        Picker(title, selection: $selection) {
            if includesAll {
                Text("Все списки").tag(0)
            }
            ForEach(lists) { list in
                Text(list.name).tag(list.id)
            }
        }
    }
}

private struct ListNameEditor: View {
    @Environment(\.dismiss) private var dismiss

    let destination: ListEditorDestination
    let store: VocabularyStore
    let onSaved: () -> Void

    @State private var name: String
    @State private var issue: VocabularyIssue?

    init(
        destination: ListEditorDestination,
        store: VocabularyStore,
        onSaved: @escaping () -> Void
    ) {
        self.destination = destination
        self.store = store
        self.onSaved = onSaved
        _name = State(initialValue: destination.initialName)
    }

    var body: some View {
        Form {
            Section {
                TextField("Название списка", text: $name)
                    .submitLabel(.done)
                    .onSubmit(save)
            }
        }
        .navigationTitle(destination.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Отмена") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Сохранить", action: save)
                    .fontWeight(.semibold)
                    .disabled(
                        name.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                    )
            }
        }
        .alert(item: $issue) { issue in
            Alert(
                title: Text("Не удалось сохранить"),
                message: Text(issue.message),
                dismissButton: .default(Text("Понятно"))
            )
        }
    }

    private func save() {
        do {
            switch destination {
            case .add:
                _ = try store.addList(named: name)
            case .rename(let list):
                try store.renameList(id: list.id, to: name)
            }
            onSaved()
            dismiss()
        } catch {
            issue = VocabularyIssue(error.localizedDescription)
        }
    }
}

private enum ListEditorDestination: Identifiable {
    case add
    case rename(VocabularyList)

    var id: String {
        switch self {
        case .add:
            "add"
        case .rename(let list):
            "rename-\(list.id)"
        }
    }

    var title: String {
        switch self {
        case .add:
            "Новый список"
        case .rename:
            "Название списка"
        }
    }

    var initialName: String {
        switch self {
        case .add:
            ""
        case .rename(let list):
            list.name
        }
    }
}

private struct VocabularyIssue: Identifiable {
    let id = UUID()
    let message: String

    init(_ message: String) {
        self.message = message
    }
}

private struct ImportSummary: Identifiable {
    let id = UUID()
    let addedCount: Int
    let message: String

    init(result: BatchImportResult) {
        addedCount = result.addedCount
        var parts = ["Добавлено: \(result.addedCount)."]
        if !result.skippedEntries.isEmpty {
            let preview = result.skippedEntries.prefix(8).joined(separator: "\n")
            let remainder = result.skippedEntries.count - min(
                result.skippedEntries.count,
                8
            )
            parts.append("Пропущено:\n\(preview)")
            if remainder > 0 {
                parts.append("И ещё \(remainder).")
            }
        }
        message = parts.joined(separator: "\n\n")
    }
}
