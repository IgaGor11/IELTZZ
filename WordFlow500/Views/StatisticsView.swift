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

                    bandCard

                    forgettingCard

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

    private var bandCard: some View {
        let mastered = store.masteredWords.count
        let band = Mastery.bandProgress(masteredCount: mastered)
        return VStack(alignment: .leading, spacing: 12) {
            Label("IELTS Band", systemImage: "trophy.fill")
                .font(.headline)

            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "Band %.1f", band.current))
                    .font(.largeTitle.bold())
                    .monospacedDigit()
                Spacer()
                Text("\(mastered) выучено • дальше \(String(format: "%.1f", band.next))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: band.progress, total: 1)
                .tint(.yellow)

            Text("Каждые 100 слов уровня 10 — +1.0 к Band.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .glassCard(padding: 18)
        .accessibilityElement(children: .combine)
    }

    private var forgettingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Кривая забывания", systemImage: "chart.line.downtrend.xyaxis")
                .font(.headline)

            ForgettingCurveChart(points: ForgettingCurve.points(for: store.words))
                .frame(height: 120)

            Text("Средняя удерживаемость слов через 30 дней.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .glassCard(padding: 18)
    }

    private var accuracyCard: some View {
        let statistics = store.statistics()
        return accuracyCardBody(statistics: statistics)
    }

    private func accuracyCardBody(statistics: LearningStatistics) -> some View {
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

private struct ForgettingCurveChart: View {
    let points: [(day: Int, retention: Double)]

    var body: some View {
        GeometryReader { geometry in
            let maxDay = Double(points.map { $0.day }.max() ?? 1)
            Path { path in
                for (index, point) in points.enumerated() {
                    let x = geometry.size.width * Double(point.day) / max(maxDay, 1)
                    let y = geometry.size.height * (1 - point.retention)
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(AppTheme.tint, lineWidth: 2.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Кривая забывания")
    }
}
