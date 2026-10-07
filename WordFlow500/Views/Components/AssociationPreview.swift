import PencilKit
import SwiftUI

struct AssociationPreview: View {
    let data: Data?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(6)
            } else {
                ContentUnavailableView(
                    "Нет рисунка",
                    systemImage: "scribble.variable",
                    description: Text("Нарисуйте ассоциацию для слова.")
                )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 138)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.secondary.opacity(0.18))
        }
        .accessibilityLabel(image == nil ? "Рисунок ассоциации отсутствует" : "Рисунок ассоциации")
    }

    private var image: UIImage? {
        guard
            let data,
            let drawing = try? PKDrawing(data: data),
            !drawing.strokes.isEmpty
        else {
            return nil
        }
        let bounds = drawing.bounds.insetBy(dx: -12, dy: -12)
        return drawing.image(from: bounds, scale: UIScreen.main.scale)
    }
}

