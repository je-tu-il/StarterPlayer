import AVFoundation
import Combine
import Speech

@MainActor
final class SpeechRecognizerManager: ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var lastRecognizedWord = ""
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var errorMessage: String?

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var sessionID: UUID?
    private var tapInstalled = false
    private var audioSessionActive = false
    private var seenNames: Set<String> = []
    private var pendingNames: Task<Void, Never>?

    private let stopWords: Set<String> = [
        "moi", "c'est", "cest", "je", "mappelle", "m'appelle", "appelle", "suis",
        "le", "la", "et", "un", "une", "ici", "bonjour", "salut", "joueur", "voici", "nom", "mon", "prenom", "prénom"
    ]

    func requestAuthorization() async -> Bool {
        let status: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard status == .authorized else { return false }
        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
    }

    func startListening(onNameDetected: @escaping @MainActor (String) -> Void) {
        guard !isListening else { return }
        errorMessage = nil
        lastRecognizedWord = ""
        guard let speechRecognizer, speechRecognizer.isAvailable, speechRecognizer.supportsOnDeviceRecognition else {
            errorMessage = "La dictée locale est indisponible. Saisissez les prénoms au clavier."
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement)
            try audioSession.setActive(true)
            audioSessionActive = true

            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                errorMessage = "Aucun microphone disponible. Saisissez les prénoms au clavier."
                stopListening()
                return
            }

            let id = UUID()
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = true
            self.request = request
            sessionID = id
            seenNames.removeAll()

            recognitionTask = speechRecognizer.recognitionTask(with: request) { @Sendable [weak self] result, error in
                let transcription = result?.bestTranscription.formattedString
                let isFinal = result?.isFinal == true
                let failed = error != nil
                Task { @MainActor in
                    guard let self, self.sessionID == id else { return }
                    self.pendingNames?.cancel()
                    if let transcription {
                        if isFinal {
                            self.process(transcription, onNameDetected: onNameDetected)
                        } else {
                            self.pendingNames = Task { @MainActor [weak self] in
                                try? await Task.sleep(for: .milliseconds(700))
                                guard !Task.isCancelled, self?.sessionID == id else { return }
                                self?.process(transcription, onNameDetected: onNameDetected)
                            }
                        }
                    }
                    if failed || isFinal { self.stopListening() }
                }
            }

            input.installTap(onBus: 0, bufferSize: 1024, format: format) { @Sendable [weak self] buffer, _ in
                request.append(buffer)
                let sample = buffer.floatChannelData?[0].pointee ?? 0
                let level = min(1, sqrt(abs(sample)) * 4)
                Task { @MainActor in
                    if self?.sessionID == id { self?.audioLevel = level }
                }
            }
            tapInstalled = true
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
        } catch {
            stopListening()
            errorMessage = "Le microphone est indisponible. Saisissez les prénoms au clavier."
        }
    }

    private func process(_ transcription: String, onNameDetected: (String) -> Void) {
        let words = transcription.split(separator: " ")
        for word in words {
            let name = word.trimmingCharacters(in: .punctuationCharacters).lowercased()
            guard name.count >= 2, !stopWords.contains(name), seenNames.insert(name).inserted else { continue }
            lastRecognizedWord = name.prefix(1).uppercased() + name.dropFirst()
            onNameDetected(lastRecognizedWord)
        }
    }

    func stopListening() {
        pendingNames?.cancel()
        pendingNames = nil
        sessionID = nil
        if tapInstalled {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        request?.endAudio()
        recognitionTask?.cancel()
        request = nil
        recognitionTask = nil
        isListening = false
        audioLevel = 0
        if audioSessionActive {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            audioSessionActive = false
        }
    }
}
