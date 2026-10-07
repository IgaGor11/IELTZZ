import SwiftUI

@MainActor
struct StudyView: View {
    let coordinator: AppCoordinator

    @State private var session = StudySession()
    @State private var presentedSheet: SheetDestination?
    @State private var hasStarted = false
    @State private var lastSpokenWordID: Int?
    @State private var activeTargetCount: Int?

    var body: some View {
        let renderedStore = coordinator.store
        let renderedSettings = coordinator.settings

        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 18) {
                    if let word = currentWord(in: renderedStore) {
                        StudyCardView(
                            word: word,
                            session: session,
                            settings: renderedSettings,
                            listName: renderedStore.listName(
                                for: word.listNumber
                            ),
                            onSpeak: {
                                coordinator.speech.speak(word.word)
                            },
                            onToggleDifficult: {
                                renderedStore.toggleDifficult(id: word.id)
                            },
                            onSaveExample: {
                                renderedStore.updateExample(
                                    $0,
                                    for: word.id
                                )
                            },
                            onOpenDrawing: { presentedSheet = .drawing(wordID: word.id) },
                            onCheck: {
                                session.checkTypedAnswer(
                                    for: word,
                                    mode: renderedSettings.studyMode,
                                    store: renderedStore,
                                    settings: renderedSettings
                                )
                            },
                            onKnow: {
                                session.selfAssess(
                                    word: word,
                                    isCorrect: true,
                                    store: renderedStore,
                                    settings: renderedSettings
                                )
                            },
                            onDontKnow: {
                                session.selfAssess(
                                    word: word,
                                    isCorrect: false,
                                    store: renderedStore,
                                    settings: renderedSettings
                                )
                            },
                            onContinue: {
                                session.continueAfterFeedback(
                                    store: renderedStore,
                                    settings: renderedSettings
                                )
                            },
                            onSkip: {
                                session.skipCurrent(
                                    store: renderedStore,
                                    settings: renderedSettings
                                )
                            },
                            onChoose: {
                                session.choose(
                                    $0,
                                    word: word,
                                    store: renderedStore,
                                    settings: renderedSettings
                                )
                            }
                        )
                        .id(word.id)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            )
                        )

                        if session.isLocked {
                            SessionStatusView(word: word, session: session)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    } else {
                        SessionCompleteView(
                            onlyDifficult: renderedSettings.onlyDifficult,
                            onRestart: {
                                activeTargetCount = nil
                                withAnimation(.snappy) {
                                    session.restart(
                                        store: renderedStore,
                                        settings: renderedSettings
                                    )
                                }
                                speakCurrentIfNeeded()
                            }
                        )
                    }
                }
                .frame(maxWidth: 760)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("500 Words")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Section("Профиль") {
                        ForEach(coordinator.profiles.profiles) { profile in
                            Button {
                                _ = coordinator.selectProfile(id: profile.id)
                            } label: {
                                if profile.id
                                    == coordinator.profiles.selectedProfileID
                                {
                                    Label(
                                        profile.name,
                                        systemImage: "checkmark"
                                    )
                                } else {
                                    Text(profile.name)
                                }
                            }
                        }
                    }
                } label: {
                    Label(
                        coordinator.activeProfile.name,
                        systemImage: "person.crop.circle"
                    )
                }
                .accessibilityIdentifier("profileMenu")
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    withAnimation(.snappy) {
                        coordinator.settings.isDarkMode.toggle()
                    }
                } label: {
                    Image(
                        systemName: coordinator.settings.isDarkMode
                            ? "sun.max.fill"
                            : "moon.fill"
                    )
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel(
                    coordinator.settings.isDarkMode
                        ? "Включить светлую тему"
                        : "Включить тёмную тему"
                )
                .accessibilityIdentifier("themeButton")

                Button {
                    presentedSheet = .settings
                } label: {
                    Image(systemName: "gearshape.fill")
                }
                .accessibilityLabel("Настройки")
                .accessibilityIdentifier("settingsButton")
            }
        }
        .sheet(item: $presentedSheet) { destination in
            switch destination {
            case .settings:
                SettingsView(coordinator: coordinator)
                    .id(coordinator.profileRevision)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            case .drawing(let wordID):
                DrawingCanvasView(
                    word: drawingWord(id: wordID, store: renderedStore)
                ) { data in
                    renderedStore.updateDrawing(data, for: wordID)
                }
            }
        }
        .onAppear {
            if startPendingNotificationSessionIfNeeded() {
                return
            }
            if hasStarted {
                session.refreshCurrent(
                    store: coordinator.store,
                    settings: coordinator.settings
                )
            } else {
                hasStarted = true
                session.start(
                    store: coordinator.store,
                    settings: coordinator.settings
                )
            }
            speakCurrentIfNeeded()
        }
        .onChange(
            of: coordinator.pendingStudySessionRequest?.id
        ) { _, requestID in
            guard requestID != nil else { return }
            _ = startPendingNotificationSessionIfNeeded()
        }
        .onChange(of: coordinator.settings.sessionSignature) { _, _ in
            withAnimation(.snappy) {
                session.restart(
                    store: coordinator.store,
                    settings: coordinator.settings,
                    targetCount: activeTargetCount
                )
            }
            lastSpokenWordID = nil
            speakCurrentIfNeeded()
        }
        .onChange(of: session.currentWordID) { _, _ in
            speakCurrentIfNeeded()
        }
        .onChange(of: coordinator.store.resetRevision) { _, _ in
            withAnimation(.snappy) {
                session.restart(
                    store: coordinator.store,
                    settings: coordinator.settings,
                    targetCount: activeTargetCount
                )
            }
            lastSpokenWordID = nil
            speakCurrentIfNeeded()
        }
        .onChange(of: coordinator.store.contentRevision) { _, _ in
            coordinator.normalizeSelectedList()
            withAnimation(.snappy) {
                session.restart(
                    store: coordinator.store,
                    settings: coordinator.settings,
                    targetCount: activeTargetCount
                )
            }
        }
        .animation(.snappy, value: session.currentWordID)
    }

    private var currentWord: VocabularyWord? {
        guard let currentWordID = session.currentWordID else { return nil }
        return coordinator.store.word(id: currentWordID)
    }

    private func currentWord(in store: VocabularyStore) -> VocabularyWord? {
        guard let currentWordID = session.currentWordID else { return nil }
        return store.word(id: currentWordID)
    }

    private func drawingWord(
        id: Int,
        store: VocabularyStore
    ) -> VocabularyWord {
        store.word(id: id)
            ?? VocabularyWord(id: id, word: "word", listNumber: 1)
    }

    @discardableResult
    private func startPendingNotificationSessionIfNeeded() -> Bool {
        guard
            let request = coordinator.takePendingStudySessionRequest()
        else {
            return false
        }

        hasStarted = true
        lastSpokenWordID = nil
        activeTargetCount = request.targetCount
        withAnimation(.snappy) {
            session.restart(
                store: coordinator.store,
                settings: coordinator.settings,
                targetCount: request.targetCount
            )
        }
        speakCurrentIfNeeded()
        return true
    }

    private func speakCurrentIfNeeded() {
        guard
            coordinator.settings.autoplayPronunciation,
            coordinator.settings.studyMode != .translationToWord,
            let word = currentWord,
            lastSpokenWordID != word.id
        else {
            return
        }
        lastSpokenWordID = word.id
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard currentWord?.id == word.id else { return }
            coordinator.speech.speak(word.word)
        }
    }
}

private struct SessionCompleteView: View {
    let onlyDifficult: Bool
    let onRestart: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: onlyDifficult ? "exclamationmark.triangle" : "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(onlyDifficult ? Color.orange : AppTheme.success)

            Text(onlyDifficult ? "Нет сложных слов для сессии" : "Сессия завершена")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text(
                onlyDifficult
                    ? "Отметьте слова как сложные или выключите фильтр в настройках."
                    : "Все слова текущей сессии обработаны. Можно начать новую."
            )
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            Button(action: onRestart) {
                Label("Начать новую сессию", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .glassCard(padding: 28)
    }
}
