import SwiftUI

@MainActor
struct StatisticsView: View {
    let store: VocabularyStore

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    StatisticsDashboard(statistics: store.statistics())

                    accuracyCard

                    if !hardestWords.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Чаще всего ошибались")
                                .font(.title3.bold())

                            ForEach(hardestWords) { word in
                                NavigationLink(
                                    value: AppRoute.wordEditor(id: word.id)
                                ) {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(word.word)
                                                .font(.headline)
                                            Text(word.trimmedTranslation)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text("\(word.incorrectCount) ошиб.")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.orange)
                                        Image(systemName: "chevron.right")
                                            .font(.caption.bold())
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .glassCard(padding: 18)
                    }
                }
                .frame(maxWidth: 760)
                .padding(16)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Статистика")
    }

    private var hardestWords: [VocabularyWord] {
        store.words
            .filter { $0.incorrectCount > 0 }
            .sorted {
                if $0.incorrectCount == $1.incorrectCount {
                    return $0.word < $1.word
                }
                return $0.incorrectCount > $1.incorrectCount
            }
            .prefix(10)
            .map { $0 }
    }

    private var accuracyCard: some View {
        let statistics = store.statistics()
        return VStack(alignment: .leading, spacing: 12) {
            Label("Ответы", systemImage: "scope")
                .font(.headline)

            ProgressView(
                value: statistics.accuracy,
                total: 100
            )
            .tint(AppTheme.success)

            HStack {
                Label(
                    "\(statistics.correctAnswers) правильных",
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundStyle(AppTheme.success)
                Spacer()
                Label(
                    "\(statistics.incorrectAnswers) ошибок",
                    systemImage: "xmark.circle.fill"
                )
                .foregroundStyle(AppTheme.error)
            }
            .font(.caption.weight(.semibold))
        }
        .glassCard(padding: 18)
    }
}
