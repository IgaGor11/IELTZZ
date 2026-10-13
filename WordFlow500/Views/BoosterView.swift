import SwiftUI
import Speech
import AVFoundation

/// Killer features IELTS: Writing Booster (абзац Task 2 + оценка Lexical Resource)
/// и Speaking Booster (голосовой ввод + проверка фразы). Всё через прокси,
/// база и офлайн-режим работают без нейросети.
@MainActor
struct BoosterView: View {
    let store: VocabularyStore
    let speech: SpeechService

    @State private var mode: BoosterMode = .writing
    @State private var paragraph = ""
    @State private var suggestions: [String] = []
    @State private var isEvaluating = false
    @State private var evaluator = AIEvaluator()
    @State private var targetWords: [String] = []

    @State private var spokenText = ""
    @State private var speakingFeedback: String?
    @State private var isRecording = false
    @State private var recognitionError: String?
    @State private var audioEngine: AVAudioEngine?
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?

    private enum BoosterMode: String, CaseIterable, Identifiable {
        case writing = "Writing"
        case speaking = "Speaking"

        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 18) {
                    Picker("Бустер", selection: $mode) {
                        ForEach(BoosterMode.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    if mode == .writing {
                        writingSection
                    } else {
                        speakingSection
                    }
                }
                .frame(maxWidth: 760)
                .padding(16)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Бустер")
        .onAppear {
            if targetWords.isEmpty {
                targetWords = Array(store.words.shuffled().prefix(3)).map(\.word)
            }
        }
    }

    private var writingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Используйте слова: \(targetWords.joined(separator: ", "))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.tint)

            TextEditor(text: $paragraph)
                .frame(minHeight: 160)
                .padding(10)
                .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier("writingEditor")

            Button {
                Task { await evaluateWriting() }
            } label: {
                Label(
                    isEvaluating ? "AI оценивает…" : "Оценить абзац",
                    systemImage: "sparkles"
                )
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .disabled(paragraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isEvaluating)
            .accessibilityIdentifier("writingEvaluateButton")

            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Lexical Resource: куда вставить сильные слова")
                        .font(.headline)
                    ForEach(Array(suggestions.enumerated()), id: \.offset) { _, item in
                        Text("• \(item)")
                            .font(.subheadline)
                    }
                }
                .glassCard(padding: 16)
            }
        }
    }

    private var speakingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let word = targetWords.first {
                HStack {
                    Text(word)
                        .font(.largeTitle.bold())
                    Spacer()
                    Button {
                        speech.speak(word)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .frame(width: 44, height: 44)
                            .background(AppTheme.tint.opacity(0.13), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Произнести слово")
                }
            }

            Text(spokenText.isEmpty ? "Произнесите слово в контексте…" : spokenText)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(spacing: 10) {
                Button {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                } label: {
                    Label(
                        isRecording ? "Стоп" : "Говорить",
                        systemImage: isRecording ? "stop.circle.fill" : "mic.circle.fill"
                    )
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 56)
                }
                .buttonStyle(.borderedProminent)
                .tint(isRecording ? AppTheme.error : AppTheme.success)
                .accessibilityIdentifier("speakingRecordButton")

                Button {
                    Task { await evaluateSpeaking() }
                } label: {
                    Label("Проверить", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 56)
                }
                .buttonStyle(.bordered)
                .disabled(spokenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isEvaluating)
            }

            TextField("Или введите фразу вручную", text: $spokenText, axis: .vertical)
                .lineLimit(1...3)
                .padding(12)
                .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            if let recognitionError {
                Text(recognitionError)
                    .font(.caption)
                    .foregroundStyle(AppTheme.error)
            }
            if let speakingFeedback {
                Text(speakingFeedback)
                    .font(.subheadline)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private func evaluateWriting() async {
        isEvaluating = true
        defer { isEvaluating = false }
        suggestions = await evaluator.evaluateWriting(paragraph: paragraph, targetWords: targetWords)
        if suggestions.isEmpty {
            suggestions = ["Нет соединения с нейросетью. Попробуйте позже — база доступна офлайн."]
        }
    }

    private func evaluateSpeaking() async {
        isEvaluating = true
        defer { isEvaluating = false }
        let word = targetWords.first ?? ""
        if let feedback = await evaluator.evaluateSpeaking(word: word, text: spokenText) {
            speakingFeedback = feedback
        } else {
            speakingFeedback = "Нет соединения с нейросетью. Попробуйте позже."
        }
    }

    private func startRecording() {
        recognitionError = nil
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable
        else {
            recognitionError = "Распознавание недоступно — введите фразу вручную."
            return
        }
        SFSpeechRecognizer.requestAuthorization { _ in }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            recognitionError = "Нет доступа к микрофону."
            return
        }
        let engine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            recognitionError = "Не удалось запустить запись."
            return
        }
        recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            if let result {
                Task { @MainActor in
                    spokenText = result.bestTranscription.formattedString
                }
            }
            if error != nil || (result?.isFinal ?? false) {
                Task { @MainActor in
                    stopRecording()
                }
            }
        }
        audioEngine = engine
        recognitionRequest = request
        isRecording = true
    }

    private func stopRecording() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
    }
}
