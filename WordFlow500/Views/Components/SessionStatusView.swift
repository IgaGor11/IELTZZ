import SwiftUI

struct SessionStatusView: View {
    let word: VocabularyWord
    let session: StudySession

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label(session.feedback.text, systemImage: feedbackIcon)
                    .font(.subheadline)
                    .foregroundStyle(feedbackColor)
                    .contentTransition(.opacity)

                Spacer(minLength: 12)

                Text("\(session.displayedPosition) / \(session.totalCount)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 7) {
                HStack {
                    Text("Уровень \(word.level) из 5")
                    Spacer()
                    Text("✓ \(word.correctCount)   ✕ \(word.incorrectCount)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                ProgressView(value: Double(word.level), total: 5)
                    .tint(levelColor)

                if session.mistakesThisSession > 0 {
                    HStack {
                        Label(
                            "Ошибок: \(session.mistakesThisSession)",
                            systemImage: "arrow.trianglehead.2.clockwise.rotate.90"
                        )
                        Spacer()
                        Text("Исправлено: \(session.correctedMistakesThisSession)")
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .animation(.snappy, value: session.feedback)
        .accessibilityElement(children: .combine)
    }

    private var feedbackIcon: String {
        switch session.feedback.tone {
        case .neutral: "info.circle.fill"
        case .success: "checkmark.circle.fill"
        case .error: "xmark.circle.fill"
        }
    }

    private var feedbackColor: Color {
        switch session.feedback.tone {
        case .neutral: .secondary
        case .success: AppTheme.success
        case .error: AppTheme.error
        }
    }

    private var levelColor: Color {
        word.level >= 3 ? AppTheme.success : AppTheme.tint
    }
}
