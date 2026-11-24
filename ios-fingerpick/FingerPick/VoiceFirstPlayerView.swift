import Foundation
import SwiftUI

struct VoiceFirstPlayerView: View {
    @Binding var currentScreen: AppScreen
    @Binding var gamePlayers: [Player]
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("fingerpick.draws.v1") private var historyData = Data()
    @StateObject private var speech = SpeechRecognizerManager()
    @State private var roster: [Player] = []
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
                            .submitLabel(.done)
                            .onSubmit(addManualName)
                        Button("Ajouter", action: addManualName)
                            .buttonStyle(.borderless)
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
            .onDisappear { speech.stopListening() }
            .sensoryFeedback(.success, trigger: winner?.id) { _, new in new != nil }
        }
    }

    private func microphone() {
        if speech.isListening {
            speech.stopListening()
            return
        }
        requesting = true
        Task { @MainActor in
            defer { requesting = false }
            let granted = await speech.requestAuthorization()
            guard currentScreen == .voicePick, scenePhase == .active else { return }
            if granted { speech.startListening(onNameDetected: addPlayer) }
            else { permissionAlert = true }
        }
    }

    private func addManualName() {
        addPlayer(name)
        name = ""
    }

    private func addPlayer(_ value: String) {
        let cleanName = String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        guard !cleanName.isEmpty, roster.count < 24,
              !roster.contains(where: { $0.name.caseInsensitiveCompare(cleanName) == .orderedSame }) else { return }
        roster.append(Player(name: cleanName, colorHex: AppPalette.hex(at: roster.count)))
    }

    private func draw() {
        speech.stopListening()
        guard roster.count >= 2, let player = roster.randomElement(),
              let index = roster.firstIndex(of: player) else { return }
        winner = player
        roster = Array(roster[index...] + roster[..<index])
        let record = DrawRecord(mode: .voice, roster: roster.map(\.id), winner: player.id,
                                lines: ["Commence : \(player.name)"])
        historyData = DrawHistory.appending(record, to: historyData)
    }
}
