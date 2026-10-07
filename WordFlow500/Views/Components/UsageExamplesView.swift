import SwiftUI

struct UsageExamplesView: View {
    let wordID: Int

    private var examples: [String] {
        SeedExamples.examples(for: wordID)
    }

    var body: some View {
        if !examples.isEmpty {
            VStack(alignment: .leading, spacing: 11) {
                Label("Примеры употребления", systemImage: "text.quote")
                    .font(.subheadline.weight(.semibold))

                ForEach(Array(examples.enumerated()), id: \.offset) { index, example in
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Text("\(index + 1)")
                            .font(.caption2.bold())
                            .foregroundStyle(AppTheme.tint)
                            .frame(width: 20, height: 20)
                            .background(AppTheme.tint.opacity(0.12), in: Circle())

                        Text(example)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                AppTheme.tint.opacity(0.07),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("usageExamples")
        }
    }
}
