import Foundation
import AVFoundation
import Speech

/// Voice input for Ask VISION: speech becomes text in the message box using
/// Apple's own speech recognition. The model itself only ever sees text.
/// Recognition stays on the phone when the device supports it; otherwise
/// iOS sends the audio to Apple to be transcribed, which `isOnDevice` lets
/// the UI say plainly.
@MainActor
final class SpeechDictation: ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var errorMessage: String?
    /// Live transcript while listening.
    @Published private(set) var transcript = ""

    private let recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer()
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    var isOnDevice: Bool { recognizer?.supportsOnDeviceRecognition ?? false }

    func toggle() {
        if isListening { stop() } else { Task { await start() } }
    }

    func start() async {
        errorMessage = nil
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition isn't available right now."
            return
        }
        guard await Self.requestSpeechAccess() else {
            errorMessage = "Allow Speech Recognition for VISION in Settings to dictate."
            return
        }
        guard await Self.requestMicrophoneAccess() else {
            errorMessage = "Allow Microphone access for VISION in Settings to dictate."
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
            self.request = request

            Self.installTap(on: engine, request: request)
            engine.prepare()
            try engine.start()

            transcript = ""
            isListening = true
            let dictation = self
            task = recognizer.recognitionTask(with: request) { result, error in
                let text = result?.bestTranscription.formattedString
                let finished = (result?.isFinal ?? false) || error != nil
                Task { @MainActor in dictation.handle(text: text, finished: finished) }
            }
        } catch {
            errorMessage = "Couldn't start the microphone."
            tearDown()
        }
    }

    func stop() {
        request?.endAudio()
        tearDown()
    }

    private func handle(text: String?, finished: Bool) {
        if let text { transcript = text }
        if finished { tearDown() }
    }

    private func tearDown() {
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        task?.cancel()
        task = nil
        request = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // The tap callback runs on an audio thread; building it in a nonisolated
    // function keeps it from inheriting main-actor isolation.
    private nonisolated static func installTap(on engine: AVAudioEngine, request: SFSpeechAudioBufferRecognitionRequest) {
        let input = engine.inputNode
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
            request.append(buffer)
        }
    }

    private nonisolated static func requestSpeechAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
    }

    private nonisolated static func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
        }
    }
}
