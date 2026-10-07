import SwiftUI

@MainActor
struct WordEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let wordID: Int
    let store: VocabularyStore
    let speech: SpeechService

    @State private var english = ""
    @State private var translation = ""
    @State private var example = ""
    @State private var listID = 1
    @State private var presentedSheet: SheetDestination?
    @State private var issueMessage: String?
    @State private var showsDeleteConfirmation = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case english
        case translation
        case example
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(word.word)
                            .font(.title2.bold())
                        Text(
                            "\(store.listName(for: word.listNumber)) • Уровень \(word.level)"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        speech.speak(word.word)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .frame(width: 42, height: 42)
                            .background(
                                AppTheme.tint.opacity(0.13),
                                in: Circle()
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Произнести \(word.word)")
                }
            }

            Section {
                if isCustomWord {
                    TextField("Английское слово", text: $english)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .english)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .translation }
                } else {
                    LabeledContent("Английское слово", value: word.word)
                }

                TextField("Перевод", text: $translation, axis: .vertical)
                    .lineLimit(1...3)
                    .focused($focusedField, equals: .translation)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .example }
                    .accessibilityIdentifier("translationField")

                TextField("Пример использования", text: $example, axis: .vertical)
                    .lineLimit(2...5)
                    .focused($focusedField, equals: .example)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
                    .accessibilityIdentifier("exampleField")

                VocabularyListPicker(
                    title: "Список",
                    selection: $listID,
                    lists: store.lists,
                    includesAll: false
                )

                Toggle(
                    "Сложное слово",
                    isOn: Binding(
                        get: { word.isDifficult },
                        set: { store.setDifficult($0, for: word.id) }
                    )
                )
            } header: {
                Text("Карточка")
            } footer: {
                Text(
                    isCustomWord
                        ? "Слово, перевод, пример и список можно изменить."
                        : "Встроенное английское слово закреплено; перевод, пример и список можно изменить."
                )
            }

            Section("Ассоциация") {
                AssociationPreview(data: word.associationDrawing)
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 8)

                Button {
                    saveEdits(showError: false)
                    presentedSheet = .drawing(wordID: word.id)
                } label: {
                    Label("Открыть холст", systemImage: "scribble.variable")
                }
                .accessibilityIdentifier("drawingButton")
            }

            if !SeedExamples.examples(for: word.id).isEmpty {
                Section("Готовые примеры употребления") {
                    UsageExamplesView(wordID: word.id)
                        .listRowInsets(EdgeInsets())
                        .padding(.vertical, 8)
                }
            }

            if !word.recentMistakes.isEmpty {
                Section("Последние ошибки") {
                    ForEach(word.recentMistakes.reversed()) { mistake in
                        MistakeRow(mistake: mistake)
                    }
                }
            }

            Section("Повторение") {
                LabeledContent("Правильных", value: "\(word.correctCount)")
                LabeledContent("Неправильных", value: "\(word.incorrectCount)")
                LabeledContent("Следующее", value: nextReviewText)
            }

            if isCustomWord {
                Section {
                    Button("Удалить слово", role: .destructive) {
                        showsDeleteConfirmation = true
                    }
                }
            }
        }
        .navigationTitle("Карточка")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Сохранить") {
                    saveEdits(showError: true)
                }
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            english = word.word
            translation = word.translation
            example = word.example
            listID = store.validListIDs.contains(word.listNumber)
                ? word.listNumber
                : store.lists.first?.id ?? 1
        }
        .onChange(of: focusedField) { oldValue, newValue in
            if oldValue != nil, newValue != oldValue {
                saveEdits(showError: false)
            }
        }
        .onDisappear {
            saveEdits(showError: false)
        }
        .sheet(item: $presentedSheet) { destination in
            switch destination {
            case .drawing(let wordID):
                DrawingCanvasView(word: word) { data in
                    store.updateDrawing(data, for: wordID)
                }
            case .settings:
                EmptyView()
            }
        }
        .confirmationDialog(
            "Удалить «\(word.word)»?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Удалить", role: .destructive) {
                do {
                    try store.deleteWord(id: word.id)
                    dismiss()
                } catch {
                    issueMessage = error.localizedDescription
                }
            }
            Button("Отмена", role: .cancel) {}
        }
        .alert(
            "Не удалось сохранить",
            isPresented: Binding(
                get: { issueMessage != nil },
                set: { if !$0 { issueMessage = nil } }
            )
        ) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text(issueMessage ?? "")
        }
    }

    private var word: VocabularyWord {
        store.word(id: wordID)
            ?? VocabularyWord(id: wordID, word: "word", listNumber: 1)
    }

    private var isCustomWord: Bool {
        word.id > SeedWords.all.count
    }

    private var nextReviewText: String {
        guard let date = word.nextReviewDate else {
            return "не запланировано"
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func saveEdits(showError: Bool) {
        let proposedEnglish = isCustomWord ? english : word.word
        guard
            proposedEnglish != word.word
                || translation != word.translation
                || example != word.example
                || listID != word.listNumber
        else {
            return
        }

        do {
            try store.updateWord(
                id: word.id,
                english: proposedEnglish,
                translation: translation,
                example: example,
                listID: listID
            )
            english = proposedEnglish
        } catch {
            if showError {
                issueMessage = error.localizedDescription
            }
        }
    }
}

private struct MistakeRow: View {
    let mistake: MistakeRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(
                mistake.submittedAnswer.map { "Ваш ответ: \($0)" }
                    ?? "Отмечено «Не знаю»"
            )
            .font(.subheadline)

            Text("Правильно: \(mistake.expectedAnswer)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let analysis = mistake.analysis {
                Text(analysis)
                    .font(.caption)
                    .foregroundStyle(AppTheme.tint)
            }

            Label(
                mistake.correctedAt == nil
                    ? "Ожидает повторения"
                    : "Исправлено",
                systemImage: mistake.correctedAt == nil
                    ? "clock.arrow.circlepath"
                    : "checkmark.circle.fill"
            )
            .font(.caption2.weight(.semibold))
            .foregroundStyle(
                mistake.correctedAt == nil
                    ? Color.orange
                    : AppTheme.success
            )

            Text(
                mistake.practicedAt.formatted(
                    date: .abbreviated,
                    time: .shortened
                )
            )
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
    }
}
