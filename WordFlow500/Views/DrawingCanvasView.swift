import PencilKit
import SwiftUI

struct DrawingCanvasView: View {
    @Environment(\.dismiss) private var dismiss

    let word: VocabularyWord
    let onSave: (Data?) -> Void

    @State private var drawing: PKDrawing
    @State private var showClearConfirmation = false

    init(word: VocabularyWord, onSave: @escaping (Data?) -> Void) {
        self.word = word
        self.onSave = onSave
        let storedDrawing = word.associationDrawing.flatMap { try? PKDrawing(data: $0) } ?? PKDrawing()
        _drawing = State(initialValue: storedDrawing)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Label("Рисуйте пальцем или Apple Pencil", systemImage: "hand.draw")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 10)

                PencilCanvas(drawing: $drawing)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.secondary.opacity(0.18))
                    }
                    .padding([.horizontal, .bottom])
            }
            .background(AppTheme.background)
            .navigationTitle(word.word)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .confirmationAction) {
                    Button {
                        showClearConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(drawing.strokes.isEmpty)
                    .accessibilityLabel("Очистить рисунок")

                    Button("Сохранить") {
                        onSave(drawing.strokes.isEmpty ? nil : drawing.dataRepresentation())
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .confirmationDialog(
                "Очистить весь рисунок?",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Очистить", role: .destructive) {
                    withAnimation {
                        drawing = PKDrawing()
                    }
                }
            }
        }
    }
}

private struct PencilCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.drawing = drawing
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .black, width: 5)
        canvas.backgroundColor = .white
        canvas.isOpaque = true
        canvas.alwaysBounceVertical = false
        canvas.alwaysBounceHorizontal = false
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        if canvas.drawing != drawing {
            canvas.drawing = drawing
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding private var drawing: PKDrawing

        init(drawing: Binding<PKDrawing>) {
            _drawing = drawing
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawing = canvasView.drawing
        }
    }
}
