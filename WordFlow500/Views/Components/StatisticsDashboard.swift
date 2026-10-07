import SwiftUI

struct StatisticsDashboard: View {
    let statistics: LearningStatistics

    private var items: [StatisticItem] {
        [
            StatisticItem(title: "Всего", value: "\(statistics.totalWords)", icon: "character.book.closed", color: .indigo),
            StatisticItem(title: "Выучено", value: "\(statistics.learnedWords)", icon: "checkmark.seal.fill", color: .green),
            StatisticItem(title: "С переводом", value: "\(statistics.translatedWords)", icon: "text.bubble.fill", color: .blue),
            StatisticItem(title: "Сложные", value: "\(statistics.difficultWords)", icon: "exclamationmark.triangle.fill", color: .orange),
            StatisticItem(
                title: "Точность",
                value: statistics.accuracy.formatted(.number.precision(.fractionLength(0))) + "%",
                icon: "scope",
                color: .cyan
            ),
            StatisticItem(title: "Сегодня", value: "\(statistics.practicedToday)", icon: "calendar", color: .mint)
        ]
    }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 104), spacing: 10)],
            spacing: 10
        ) {
            ForEach(items) { item in
                StatisticTile(item: item)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Статистика обучения")
    }
}

private struct StatisticItem: Identifiable {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var id: String { title }
}

private struct StatisticTile: View {
    let item: StatisticItem

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: item.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(item.color)

            Text(item.value)
                .font(.title3.bold())
                .contentTransition(.numericText())

            Text(item.title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title): \(item.value)")
    }
}

