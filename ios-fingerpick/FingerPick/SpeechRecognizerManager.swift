import SwiftUI
import Speech
import AVFoundation
import Combine

@MainActor
final class SpeechRecognizerManager: ObservableObject {
    @Published var isListening: Bool = false
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var lastRecognizedWord: String = ""
    @Published var audioLevel: Float = 0.0
    @Published var errorMessage: String? = nil
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Words to ignore if spoken in phrases like "Moi c'est Lucas", "Je m'appelle Sarah"
    private let stopWords: Set<String> = [
        "moi", "c'est", "cest", "je", "mappelle", "m'appelle", "appelle",
        "suis", "le", "la", "et", "un", "une", "ici", "bonjour", "salut",
        "joueur", "voici", "nom", "mon", "prenom", "prénom"
    ]
    
    init() {
        checkAuthorization()
    }
    
    func checkAuthorization() {
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    }
    
    func requestAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    self.authorizationStatus = status
                    if status == .authorized {
                        AVAudioApplication.requestRecordPermission { granted in
                            continuation.resume(returning: granted)
                        }
                    } else {
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }
    
    func toggleListening(onNameDetected: @escaping (String) -> Void) {
        if isListening {
            stopListening()
        } else {
            startListening(onNameDetected: onNameDetected)
        }
    }
    
    func startListening(onNameDetected: @escaping (String) -> Void) {
        guard !isListening else { return }
        
        // Reset state
        errorMessage = nil
        lastRecognizedWord = ""
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Erreur session audio: \(error.localizedDescription)"
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        
        var recordedNamesSoFar = Set<String>()
        var lastWordCount = 0
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                let words = transcription.split(separator: " ").map { String($0) }
                
                if words.count > lastWordCount, let lastWord = words.last {
                    lastWordCount = words.count
                    self.processWordCandidate(lastWord, seen: &recordedNamesSoFar, onDetected: onNameDetected)
                }
            }
            
            if error != nil || (result?.isFinal ?? false) {
                // If audio finished or silent, keep ready
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            
            // Calculate approximate audio power level
            if let channelData = buffer.floatChannelData?[0] {
                let channelDataValue = channelData.pointee
                let rms = sqrt(abs(channelDataValue))
                Task { @MainActor in
                    self?.audioLevel = min(1.0, max(0.1, rms * 4.0))
                }
            }
        }
        
        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
        } catch {
            errorMessage = "Impossible de démarrer le micro: \(error.localizedDescription)"
            stopListening()
        }
    }
    
    private func processWordCandidate(_ word: String, seen: inout Set<String>, onDetected: (String) -> Void) {
        let cleaned = word.trimmingCharacters(in: .punctuationCharacters).lowercased()
        guard cleaned.count >= 2, !stopWords.contains(cleaned) else { return }
        
        // Capitalize first letter
        let capitalized = cleaned.prefix(1).uppercased() + cleaned.dropFirst()
        
        if !seen.contains(capitalized.lowercased()) {
            seen.insert(capitalized.lowercased())
            lastRecognizedWord = capitalized
            onDetected(capitalized)
        }
    }
    
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
        audioLevel = 0.0
    }
}
