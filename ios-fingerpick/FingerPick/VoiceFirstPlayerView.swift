import Foundation
import SwiftUI

struct VoiceFirstPlayerView: View {
    @Binding var currentScreen: AppScreen
    @Binding var gamePlayers: [Player]
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("fingerpick.draws.v1") private var historyData = Data()
    @StateObject private var speech = SpeechRecognizerManager()
    @AppStorage("fingerpick.voiceNames.v1") private var recentNamesData = Data()
    @AppStorage("fingerpick.voiceGroup.v1") private var savedGroupData = Data()
    @State private var roster: [Player] = []
    @FocusState private var isNameFieldFocused: Bool
    @State private var name = ""
    @State private var winner: Player?
    @State private var requesting = false
    @State private var permissionAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section("Inscription") {
                    Button(speech.isListening ? "Arrêter le microphone" : "Dicter les prénoms",
                           systemImage: speech.isListening ? "stop.circle" : "mic", action: microphone)
                        .disabled(requesting)
                    if speech.isListening {
                        Label("Le microphone est actif", systemImage: "waveform")
                    }
                    if let error = speech.errorMessage {
                        Text(error).foregroundStyle(.secondary)
                    }
                    HStack {
                        TextField("Prénom", text: $name)
                            .focused($isNameFieldFocused)
                            .submitLabel(.done)
                            .onSubmit(addManualName)
                        Button("Ajouter", action: addManualName)
                            .buttonStyle(.borderless)
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                if isNameFieldFocused && !suggestions.isEmpty {
                    Section("Prénoms récents") {
                        ForEach(Array(suggestions.prefix(5)), id: \.self) { suggestion in
                            Button(suggestion) {
                                name = suggestion
                                addManualName()
                            }
                        }
                    }
                }
                if roster.count >= 2 {
                    Button("Mémoriser ce groupe", systemImage: "person.2") {
                        savedGroupData = (try? JSONEncoder().encode(roster)) ?? savedGroupData
                    }
                }
                if roster.isEmpty && !savedGroupData.isEmpty {
                    Button("Reprendre le groupe mémorisé", systemImage: "person.2.fill") {
                        roster = (try? JSONDecoder().decode([Player].self, from: savedGroupData)) ?? []
                    }
                }

                Section("Ordre de table") {
                    ForEach(roster) { player in
                        Label(player.name, systemImage: winner?.id == player.id ? "crown.fill" : "person")
                    }
                    .onDelete { roster.remove(atOffsets: $0) }
                    .onMove { roster.move(fromOffsets: $0, toOffset: $1) }
                }

                Section("Tirage") {
                    Button("Tirer le premier joueur", systemImage: "shuffle", action: draw)
                        .disabled(roster.count < 2)
                    if let winner {
                        Text("Commence : \(winner.name)").font(.headline)
                    }
                    Button("Bibliothèque de scores", systemImage: "list.clipboard") {
                        gamePlayers = roster
                        currentScreen = .gameSelection
                    }
                    .disabled(roster.isEmpty)
                }
            }
            .navigationTitle("Tirage vocal")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Tirage", systemImage: "chevron.left") {
                        gamePlayers = roster
                        currentScreen = .drawHome
                    }
                }
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
            .alert("Accès au microphone", isPresented: $permissionAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Autorisez le microphone et la reconnaissance vocale dans Réglages ou ajoutez les joueurs au clavier.")
            }
            .onAppear { roster = gamePlayers }
            .onChange(of: roster) {
                if let winner, !roster.contains(where: { $0.id == winner.id }) { self.winner = nil }
            }
            .onChange(of: scenePhase) {
                if scenePhase != .active { speech.stopListening() }
            }
            .onChange(of: isNameFieldFocused) {
                if isNameFieldFocused { speech.stopListening() }
            }
            .onDisappear { speech.stopListening() }
            .sensoryFeedback(.success, trigger: winner?.id) { _, new in new != nil }
        }
    }

    private func microphone() {
        if speech.isListening {
            speech.stopListening()
            return
        }
        isNameFieldFocused = false
        requesting = true
        Task { @MainActor in
            defer { requesting = false }
            let granted = await speech.requestAuthorization()
            guard currentScreen == .voicePick, scenePhase == .active, !isNameFieldFocused else { return }
            if granted { speech.startListening(onNameDetected: addPlayer) }
            else { permissionAlert = true }
        }
    }

    private var recentNames: [String] {
        (try? JSONDecoder().decode([String].self, from: recentNamesData)) ?? []
    }

    private var suggestions: [String] {
        guard !name.isEmpty else { return [] }
        return recentNames.filter { saved in
            saved.range(of: name, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) != nil &&
            !roster.contains { $0.name.caseInsensitiveCompare(saved) == .orderedSame }
        }
    }

    private func addManualName() {
        addPlayer(name)
        name = ""
    }

    private func addPlayer(_ value: String) {
        let cleanName = String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        guard !cleanName.isEmpty,
              !roster.contains(where: { $0.name.caseInsensitiveCompare(cleanName) == .orderedSame }) else { return }
        roster.append(Player(name: cleanName, colorHex: AppPalette.hex(at: roster.count)))
        var updatedNames = recentNames.filter { $0.caseInsensitiveCompare(cleanName) != .orderedSame }
        updatedNames.insert(cleanName, at: 0)
        recentNamesData = (try? JSONEncoder().encode(Array(updatedNames.prefix(60)))) ?? recentNamesData
    }

    private func draw() {
        speech.stopListening()
        guard roster.count >= 2, let player = roster.randomElement() else { return }
        winner = player
        let record = DrawRecord(mode: .voice, roster: roster.map(\.id), winner: player.id,
                                lines: ["Commence : \(player.name)"])
        historyData = DrawHistory.appending(record, to: historyData)
    }
}
