import SwiftUI

struct StudyCardView: View {
    let word: VocabularyWord
    @Bindable var session: StudySession
    let settings: AppSettings
    let listName: String
    let onSpeak: () -> Void
    let onToggleDifficult: () -> Void
    let onSaveExample: (String) -> Void
    let onOpenDrawing: () -> Void
    let onCheck: () -> Void
    let onKnow: () -> Void
    let onDontKnow: () -> Void
    let onContinue: () -> Void
    let onSkip: () -> Void
    let onChoose: (ChoiceOption) -> Void

    @State private var exampleDraft: String
    @State private var lastPersistedExample: String
    @State private var extrasExpanded = false
    @FocusState private var focusedField: FocusField?

    private enum FocusField {
        case answer
        case example
    }

    init(
        word: VocabularyWord,
        session: StudySession,
        settings: AppSettings,
        listName: String,
        onSpeak: @escaping () -> Void,
        onToggleDifficult: @escaping () -> Void,
        onSaveExample: @escaping (String) -> Void,
        onOpenDrawing: @escaping () -> Void,
        onCheck: @escaping () -> Void,
        onKnow: @escaping () -> Void,
        onDontKnow: @escaping () -> Void,
        onContinue: @escaping () -> Void,
        onSkip: @escaping () -> Void,
        onChoose: @escaping (ChoiceOption) -> Void
    ) {
        self.word = word
        self.session = session
        self.settings = settings
        self.listName = listName
        self.onSpeak = onSpeak
        self.onToggleDifficult = onToggleDifficult
        self.onSaveExample = onSaveExample
        self.onOpenDrawing = onOpenDrawing
        self.onCheck = onCheck
        self.onKnow = onKnow
        self.onDontKnow = onDontKnow
        self.onContinue = onContinue
        self.onSkip = onSkip
        self.onChoose = onChoose
        _exampleDraft = State(initialValue: word.example)
        _lastPersistedExample = State(initialValue: word.example)
    }

    var body: some View {
        VStack(spacing: 22) {
            prompt

            if canPractice {
                practiceControls
            } else {
                missingTranslation
            }

            if session.isAnswerRevealed {
                VStack(spacing: 12) {
                    revealedAnswer
                    UsageExamplesView(wordID: word.id)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if canPractice {
                selfAssessmentControls
            }

            DisclosureGroup(isExpanded: $extrasExpanded) {
                VStack(spacing: 16) {
                    Divider()
                    cardHeader
                    exampleEditor
                    associationControls

                    NavigationLink(value: AppRoute.wordEditor(id: word.id)) {
                        Label(
                            "Редактировать карточку",
                            systemImage: "square.and.pencil"
                        )
                        .font(.subheadline)
                    }
                }
                .padding(.top, 8)
            } label: {
                Label(
                    "Ваш пример и иллюстрация",
                    systemImage: "chevron.down.circle"
                )
                .font(.subheadline.weight(.semibold))
            }
            .accessibilityIdentifier("cardExtrasDisclosure")
        }
        .glassCard(padding: 22)
        .onChange(of: focusedField) { oldValue, newValue in
            if oldValue == .example, newValue != .example {
                saveExampleIfNeeded()
            }
        }
        .onChange(of: word.example) { _, newValue in
            if exampleDraft == lastPersistedExample {
                exampleDraft = newValue
            }
            lastPersistedExample = newValue
        }
        .animation(.snappy, value: session.isAnswerRevealed)
    }

    private var cardHeader: some View {
        HStack {
            Label(listName, systemImage: "list.number")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.quaternary, in: Capsule())

            Spacer()

            Button(action: onToggleDifficult) {
                Image(systemName: word.isDifficult ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                    .foregroundStyle(word.isDifficult ? .orange : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(word.isDifficult ? "Снять отметку сложного слова" : "Отметить как сложное")
        }
    }

    private var prompt: some View {
        VStack(spacing: 12) {
            Text(settings.studyMode.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(alignment: .center, spacing: 12) {
                Text(promptText)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.62)

                Button(action: onSpeak) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .background(AppTheme.tint.opacity(0.13), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Произнести английское слово")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var revealedAnswer: some View {
        VStack(spacing: 5) {
            Text("Правильный ответ")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(answerText)
                .font(.title3.bold())
                .foregroundStyle(answerText == "Перевод пока не задан" ? .secondary : .primary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppTheme.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var exampleEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Ваш пример", systemImage: "quote.bubble")
                .font(.subheadline.weight(.semibold))

            TextField(
                "Напишите своё предложение с этим словом",
                text: $exampleDraft,
                axis: .vertical
            )
            .lineLimit(2...4)
            .textInputAutocapitalization(.sentences)
            .focused($focusedField, equals: .example)
            .submitLabel(.done)
            .onSubmit {
                focusedField = nil
            }
            .padding(12)
            .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    @ViewBuilder
    private var practiceControls: some View {
        if settings.studyMode == .multipleChoice {
            choiceGrid
        } else {
            answerInput
        }
    }

    private var answerInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Ваш ответ", systemImage: "keyboard")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 10) {
                TextField(settings.studyMode.answerPlaceholder, text: $session.typedAnswer)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .answer)
                    .submitLabel(.done)
                    .onSubmit(onCheck)
                    .disabled(session.isLocked)

                Button("Проверить", action: onCheck)
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        session.typedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || session.isLocked
                    )
            }
            .padding(12)
            .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var choiceGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Выберите перевод", systemImage: "checklist")
                .font(.subheadline.weight(.semibold))

            ForEach(session.options) { option in
                Button {
                    onChoose(option)
                } label: {
                    HStack {
                        Text(option.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if session.isLocked, option.isCorrect {
                            Image(systemName: "checkmark.circle.fill")
                        } else if session.isLocked, session.selectedOptionID == option.id {
                            Image(systemName: "xmark.circle.fill")
                        }
                    }
                    .font(.body.weight(.medium))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 50)
                    .background(optionBackground(option), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(optionBorder(option), lineWidth: 1.5)
                    }
                }
                .buttonStyle(.plain)
                .disabled(session.isLocked)
                .accessibilityLabel("Вариант: \(option.text)")
            }
        }
    }

    private var missingTranslation: some View {
        VStack(spacing: 11) {
            Image(systemName: "text.badge.plus")
                .font(.title2)
                .foregroundStyle(AppTheme.tint)
            Text("Для этого режима сначала добавьте перевод.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            NavigationLink("Добавить перевод", value: AppRoute.wordEditor(id: word.id))
                .buttonStyle(.borderedProminent)

            Button("Пропустить", action: onSkip)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var selfAssessmentControls: some View {
        VStack(spacing: 10) {
            if session.isLocked {
                Button(action: onContinue) {
                    Label("Следующее слово", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("continueButton")
            } else {
                HStack(spacing: 10) {
                    Button(action: onDontKnow) {
                        Label("Не знаю", systemImage: "xmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.error)
                    .accessibilityIdentifier("dontKnowButton")

                    Button(action: onKnow) {
                        Label("Знаю", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.success)
                    .accessibilityIdentifier("knowButton")
                }

                Button {
                    session.showAnswer(for: word, mode: settings.studyMode)
                } label: {
                    Label("Показать ответ", systemImage: "eye")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var associationControls: some View {
        VStack(spacing: 10) {
            if settings.showsDrawingCanvas {
                AssociationPreview(data: word.associationDrawing)
            }

            Button(action: onOpenDrawing) {
                Label(
                    word.associationDrawing == nil ? "Нарисовать ассоциацию" : "Изменить ассоциацию",
                    systemImage: "scribble.variable"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var promptText: String {
        switch settings.studyMode {
        case .wordToTranslation, .multipleChoice:
            word.word
        case .translationToWord:
            word.hasTranslation ? word.trimmedTranslation : "Перевод не задан"
        case .spelling:
            word.hasTranslation ? word.trimmedTranslation : "Прослушайте слово"
        }
    }

    private var answerText: String {
        switch settings.studyMode {
        case .wordToTranslation, .multipleChoice:
            word.hasTranslation ? word.trimmedTranslation : "Перевод пока не задан"
        case .translationToWord, .spelling:
            word.word
        }
    }

    private var canPractice: Bool {
        switch settings.studyMode {
        case .wordToTranslation, .translationToWord:
            word.hasTranslation
        case .multipleChoice:
            session.options.count == 4
        case .spelling:
            true
        }
    }

    private func optionBackground(_ option: ChoiceOption) -> Color {
        switch session.optionState(option) {
        case .success:
            AppTheme.success.opacity(0.17)
        case .error:
            AppTheme.error.opacity(0.17)
        case .neutral, nil:
            Color.primary.opacity(0.04)
        }
    }

    private func optionBorder(_ option: ChoiceOption) -> Color {
        switch session.optionState(option) {
        case .success:
            AppTheme.success
        case .error:
            AppTheme.error
        case .neutral, nil:
            Color.secondary.opacity(0.20)
        }
    }

    private func saveExampleIfNeeded() {
        guard exampleDraft != lastPersistedExample else { return }
        onSaveExample(exampleDraft)
        lastPersistedExample = exampleDraft
    }
}
