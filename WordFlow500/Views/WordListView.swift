import SwiftUI

@MainActor
struct WordListView: View {
    let store: VocabularyStore
    @Bindable var settings: AppSettings
    let onListsChanged: () -> Void

    @State private var searchText = ""
    @State private var presentedSheet: WordListSheet?
    @State private var wordPendingDeletion: VocabularyWord?
    @State private var deletionError: String?

    init(
        store: VocabularyStore,
        settings: AppSettings,
        onListsChanged: @escaping () -> Void = {}
    ) {
        self.store = store
        _settings = Bindable(wrappedValue: settings)
        self.onListsChanged = onListsChanged
    }

    var body: some View {
        List {
            Section {
                VocabularyListPicker(
                    title: "Показывать",
                    selection: $settings.selectedList,
                    lists: store.lists,
                    includesAll: true
                )
                .pickerStyle(.menu)
                .accessibilityIdentifier("wordListPicker")
            }

            Section("\(filteredWords.count) слов") {
                ForEach(filteredWords) { word in
                    NavigationLink(value: AppRoute.wordEditor(id: word.id)) {
                        WordRow(
                            word: word,
                            listName: store.listName(for: word.listNumber)
                        )
                    }
                    .accessibilityIdentifier("wordRow-\(word.id)")
                    .swipeActions {
                        if word.id > SeedWords.all.count {
                            Button(role: .destructive) {
                                wordPendingDeletion = word
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .navigationTitle("Слова")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Слово или перевод")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        presentedSheet = .addWord
                    } label: {
                        Label("Добавить слово", systemImage: "plus")
                    }

                    Button {
                        presentedSheet = .batchImport
                    } label: {
                        Label(
                            "Добавить пачкой",
                            systemImage: "text.badge.plus"
                        )
                    }

                    Divider()

                    Button {
                        presentedSheet = .manageLists
                    } label: {
                        Label(
                            "Управление списками",
                            systemImage: "folder.badge.gearshape"
                        )
                    }
                } label: {
                    Label("Добавить", systemImage: "plus")
                }
                .accessibilityIdentifier("vocabularyActionsButton")
            }
        }
        .overlay {
            if filteredWords.isEmpty {
                if searchText.isEmpty {
                    ContentUnavailableView(
                        "В этом списке пока нет слов",
                        systemImage: "text.book.closed",
                        description: Text(
                            "Добавьте одно слово или импортируйте сразу несколько."
                        )
                    )
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .addWord:
                    AddWordView(
                        store: store,
                        initialListID: preferredListID
                    )
                case .batchImport:
                    BatchImportView(
                        store: store,
                        initialListID: preferredListID
                    )
                case .manageLists:
                    ListManagementView(store: store) {
                        settings.normalizeSelectedList(
                            validListIDs: store.validListIDs
                        )
                        onListsChanged()
                    }
                }
            }
            .presentationDetents([.large])
        }
        .confirmationDialog(
            "Удалить слово «\(wordPendingDeletion?.word ?? "")»?",
            isPresented: Binding(
                get: { wordPendingDeletion != nil },
                set: { if !$0 { wordPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Удалить", role: .destructive) {
                guard let wordPendingDeletion else { return }
                do {
                    try store.deleteWord(id: wordPendingDeletion.id)
                    self.wordPendingDeletion = nil
                } catch {
                    deletionError = error.localizedDescription
                }
            }
            Button("Отмена", role: .cancel) {
                wordPendingDeletion = nil
            }
        }
        .alert(
            "Не удалось удалить слово",
            isPresented: Binding(
                get: { deletionError != nil },
                set: { if !$0 { deletionError = nil } }
            )
        ) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text(deletionError ?? "")
        }
        .onAppear {
            settings.normalizeSelectedList(validListIDs: store.validListIDs)
        }
        .onChange(of: store.contentRevision) { _, _ in
            settings.normalizeSelectedList(validListIDs: store.validListIDs)
        }
    }

    private var preferredListID: Int? {
        if settings.selectedList != 0,
            store.validListIDs.contains(settings.selectedList)
        {
            return settings.selectedList
        }
        return store.lists.first?.id
    }

    private var filteredWords: [VocabularyWord] {
        let listWords = store.words.filter {
            settings.selectedList == 0 || $0.listNumber == settings.selectedList
        }
        let query = AnswerMatcher.normalized(searchText)
        guard !query.isEmpty else { return listWords }
        return listWords.filter {
            AnswerMatcher.normalized($0.word).contains(query)
                || AnswerMatcher.normalized($0.translation).contains(query)
        }
    }
}

private struct WordRow: View {
    let word: VocabularyWord
    let listName: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(word.word)
                        .font(.headline)
                    if word.isDifficult {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .accessibilityLabel("Сложное слово")
                    }
                }

                Text(
                    word.hasTranslation
                        ? word.trimmedTranslation
                        : "Перевод не задан"
                )
                .font(.subheadline)
                .foregroundStyle(
                    word.hasTranslation ? .secondary : .tertiary
                )
                .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Ур. \(word.level)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(
                        word.level >= 3 ? AppTheme.success : AppTheme.tint
                    )
                Text(listName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

private enum WordListSheet: String, Identifiable {
    case addWord
    case batchImport
    case manageLists

    var id: String { rawValue }
}
