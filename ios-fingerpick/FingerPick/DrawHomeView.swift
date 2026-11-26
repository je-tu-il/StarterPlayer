import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct DrawHomeView: View {
    @Binding var screen: AppScreen
    @Binding var players: [Player]
    @AppStorage("fingerpick.draws.v1") private var savedHistory = Data()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var history: [DrawRecord] = []
    @State private var rosterName = ""
    @State private var mode = DrawMode.random
    @State private var teamCount = 2
    @State private var wheelAngle = 0.0
    @State private var result: DrawRecord?
    @State private var editPlayer: Player?
    @State private var clearHistory = false
    @State private var spinning = false
    @State private var exporting = false
    @State private var importing = false
    @State private var pendingBackup: ScoreBackup?
    @State private var confirmRestore = false
    @State private var backupMessage: String?
    @State private var exportBackup: ScoreBackup?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { screen = .gameSelection } label: {
                        Label("Bibliothèque de scores", systemImage: "list.clipboard")
                    }
                    .accessibilityIdentifier("draw.scoreLibrary")
                    Button { screen = .fingerPick } label: {
                        Label("Tirage tactile", systemImage: "hand.tap")
                    }
                    Button { screen = .voicePick } label: {
                        Label("Inscription vocale", systemImage: "mic")
                    }
                }

                Section("Joueurs") {
                    ForEach(players) { player in
                        Button {
                            editPlayer = player
                        } label: {
                            Label {
                                Text(player.name).foregroundStyle(.primary)
                            } icon: {
                                Image(systemName: "circle.fill").foregroundStyle(player.color)
                            }
                        }
                        .accessibilityHint("Modifier le joueur")
                    }
                    .onMove { players.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { players.remove(atOffsets: $0) }
                    if players.count < 52 {
                        HStack {
                            TextField("Prénom", text: $rosterName)
                                .submitLabel(.done)
                                .onSubmit(addPlayer)
                            Button("Ajouter", action: addPlayer)
                                .buttonStyle(.borderless)
                                .disabled(rosterName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }

                Section("Tirage") {
                    Picker("Mode", selection: $mode) {
                        ForEach(DrawMode.selectable, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    if mode == .teams && players.count >= 2 {
                        Stepper("Équipes : \(teamCount)", value: $teamCount, in: 2...min(8, players.count))
                    }
                    Text(mode.instructions).font(.subheadline).foregroundStyle(.secondary)
                    if mode == .wheel && players.count >= 2 {
                        DrawWheel(players: players, angle: wheelAngle)
                            .frame(height: 220)
                            .accessibilityHidden(true)
                    }
                    Button("Lancer le tirage", systemImage: "play.fill", action: draw)
                        .disabled(players.count < 2 || players.count > 52 || spinning)
                    if players.count < 2 {
                        Text("Ajoutez au moins deux joueurs.").font(.footnote).foregroundStyle(.secondary)
                    }
                }

                if let result {
                    Section("Résultat") {
                        ForEach(Array(result.lines.enumerated()), id: \.offset) { _, line in Text(line) }
                    }
                }

                Section("Sauvegarde") {
                    Button("Exporter une sauvegarde", systemImage: "square.and.arrow.up") {
                        exportBackup = ScoreBackup()
                        exporting = true
                    }
                    Button("Restaurer une sauvegarde", systemImage: "square.and.arrow.down") {
                        importing = true
                    }
                }

                if !history.isEmpty {
                    Section("Historique") {
                        ForEach(history) { record in
                            DisclosureGroup {
                                ForEach(Array(record.lines.enumerated()), id: \.offset) { _, line in Text(line) }
                            } label: {
                                LabeledContent(record.mode.rawValue) {
                                    Text(record.date, format: .dateTime.day().month().hour().minute())
                                }
                            }
                        }
                        Button("Effacer l’historique", role: .destructive) { clearHistory = true }
                    }
                }
            }
            .disabled(spinning)
            .navigationTitle("Qui commence ?")
            .toolbar { if players.count > 1 { EditButton().disabled(spinning) } }
            .sheet(item: $editPlayer) { player in
                PlayerEditSheet(player: player) { updated in
                    if let index = players.firstIndex(where: { $0.id == updated.id }) { players[index] = updated }
                } onDelete: {
                    players.removeAll { $0.id == player.id }
                }
            }
            .confirmationDialog("Effacer l’historique des tirages ?", isPresented: $clearHistory) {
                Button("Effacer", role: .destructive) {
                    history.removeAll()
                    savedHistory = Data()
                }
            }
            .onAppear {
                history = DrawHistory.read(savedHistory)
            }
            .fileExporter(isPresented: $exporting, document: exportBackup,
                          contentType: .json, defaultFilename: "FingerPick-sauvegarde") { result in
                if case .failure(let error) = result { backupMessage = error.localizedDescription }
                exportBackup = nil
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do {
                    pendingBackup = try ScoreBackup(url: result.get())
                    confirmRestore = true
                } catch {
                    backupMessage = "Impossible d’ouvrir ce fichier de sauvegarde."
                }
            }
            .confirmationDialog("Remplacer les joueurs, les scores et l’historique actuels ?",
                                isPresented: $confirmRestore, titleVisibility: .visible) {
                Button("Restaurer", role: .destructive) {
                    pendingBackup?.restore()
                    history = DrawHistory.read(UserDefaults.standard.data(forKey: "fingerpick.draws.v1") ?? Data())
                    result = nil
                    pendingBackup = nil
                }
                Button("Annuler", role: .cancel) { pendingBackup = nil }
            }
            .alert("Sauvegarde", isPresented: Binding(
                get: { backupMessage != nil }, set: { if !$0 { backupMessage = nil } }
            )) {
                Button("OK", role: .cancel) { backupMessage = nil }
            } message: {
                Text(backupMessage ?? "")
            }
            .onChange(of: mode) { result = nil }
            .onChange(of: players) {
                teamCount = max(2, min(teamCount, players.count))
                result = nil
            }
            .sensoryFeedback(.success, trigger: result?.id) { _, new in new != nil }
        }
    }

    private func addPlayer() {
        let name = rosterName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, players.count < 52 else { return }
        players.append(Player(name: String(name.prefix(40)), colorHex: AppPalette.hex(at: players.count)))
        rosterName = ""
    }

    private func draw() {
        var generator = SystemRandomNumberGenerator()
        guard let record = DrawEngine.generate(mode: mode, roster: players, history: history,
                                               teamCount: teamCount, using: &generator) else { return }
        savedHistory = DrawHistory.appending(record, to: savedHistory)
        history = DrawHistory.read(savedHistory)

        guard mode == .wheel, let index = players.firstIndex(where: { $0.id == record.winner }) else {
            result = record
            return
        }

        let end = ceil(wheelAngle / 360) * 360 + 1080 - Double(index) * 360 / Double(players.count)
        withAnimation(reduceMotion ? nil : .timingCurve(0.12, 0.72, 0.19, 1, duration: 1.8)) { wheelAngle = end }
        if reduceMotion {
            result = record
        } else {
            spinning = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                spinning = false
                if mode == .wheel && players.map(\.id) == record.roster { result = record }
            }
        }
    }
}

private struct DrawWheel: View {
    let players: [Player]
    let angle: Double

    var body: some View {
        ZStack(alignment: .top) {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - 10
                let step = 360 / Double(players.count)
                for (index, player) in players.enumerated() {
                    let heading = Double(index) * step - 90
                    var slice = Path()
                    slice.move(to: center)
                    slice.addArc(center: center, radius: radius,
                                 startAngle: .degrees(heading - step / 2), endAngle: .degrees(heading + step / 2),
                                 clockwise: false)
                    slice.closeSubpath()
                    context.fill(slice, with: .color(player.color))
                    let radians = heading * .pi / 180
                    let point = CGPoint(x: center.x + radius * 0.75 * cos(radians),
                                        y: center.y + radius * 0.75 * sin(radians))
                    context.draw(Text("\(index + 1)").font(.caption.bold()).foregroundColor(.black), at: point)
                }
            }
            .rotationEffect(.degrees(angle))
            Image(systemName: "arrowtriangle.down.fill")
                .font(.title2)
                .foregroundStyle(.primary)
        }
    }
}
