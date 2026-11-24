import Foundation
import SwiftUI

struct CatalogRound: Identifiable, Codable, Equatable {
    var id = UUID()
    var entries: [UUID: [Int]] = [:]
}

struct CatalogMatch: Codable, Equatable {
    var players: [Player]
    var rounds = [CatalogRound()]

    func canScore(_ round: CatalogRound, for game: ScoreGame) -> Bool {
        if game.rule == .skyjo {
            let values = players.compactMap { round.entries[$0.id] }
            return values.count == players.count && values.filter { $0.last == 1 }.count == 1
        }
        return true
    }

    func points(in round: CatalogRound, for player: Player, game: ScoreGame) -> Int? {
        guard let values = round.entries[player.id], canScore(round, for: game) else { return nil }
        if game.rule == .skyjo {
            let scores = players.compactMap { round.entries[$0.id]?.first }
            let minimum = scores.min()
            return game.score(values, skyjoMinimum: minimum, minimumCount: scores.filter { $0 == minimum }.count)
        }
        return game.score(values)
    }

    func total(for player: Player, game: ScoreGame) -> Int {
        rounds.compactMap { points(in: $0, for: player, game: game) }.reduce(0, +)
    }

    func phases(for player: Player) -> Int {
        min(10, rounds.compactMap { $0.entries[player.id]?.first }.reduce(0, +))
    }
}

struct CatalogScoreView: View {
    let game: ScoreGame
    let roster: [Player]
    @AppStorage private var saved: Data
    @State private var match: CatalogMatch
    @State private var selectedCell: Cell?
    @State private var confirmReset = false
    @State private var storageError = false

    init(game: ScoreGame, players: [Player]) {
        self.game = game
        roster = game.rule.isSingle ? [
            Player(name: "Équipe", colorHex: AppPalette.hex(at: 0))
        ] : players
        let storage = AppStorage(wrappedValue: Data(), "fingerpick.catalog.v1.\(game.id)")
        _saved = storage
        _match = State(initialValue: (try? JSONDecoder().decode(CatalogMatch.self, from: storage.wrappedValue))
            ?? CatalogMatch(players: roster))
    }

    var body: some View {
        List {
            Section {
                Text(game.instructions)
                if let target = game.target {
                    let reached = match.players.contains {
                        game.rule == .phase ? match.phases(for: $0) >= target : match.total(for: $0, game: game) >= target
                    }
                    Label(reached ? "Seuil atteint : \(target)" : "Seuil : \(target)",
                          systemImage: reached ? "flag.checkered" : "flag")
                }
            } header: {
                Text("Décompte")
            }

            Section(game.rule.isSingle ? "Bilan" : "Classement provisoire") {
                ForEach(rankedPlayers) { player in
                    LabeledContent(player.name) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(game.display(match.total(for: player, game: game)))
                                .monospacedDigit()
                            if game.rule == .phase {
                                Text("\(match.phases(for: player)) / 10 phases")
                                    .font(.caption)
                            }
                        }
                    }
                }
            }

            ForEach(Array(match.rounds.enumerated()), id: \.element.id) { index, round in
                Section {
                    ForEach(match.players) { player in
                        Button {
                            selectedCell = Cell(roundID: round.id, player: player, values: round.entries[player.id])
                        } label: {
                            LabeledContent(player.name) {
                                if let score = match.points(in: round, for: player, game: game) {
                                    Text(game.display(score)).monospacedDigit()
                                } else {
                                    Text(round.entries[player.id] == nil ? "Saisir" : "Modifier")
                                }
                            }
                        }
                        .accessibilityHint("Modifie la saisie de ce joueur")
                    }
                    if !round.entries.isEmpty && !match.canScore(round, for: game) {
                        Label("Renseignez tous les joueurs et indiquez une seule clôture.",
                              systemImage: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                    if round.entries.isEmpty && match.rounds.count > 1 {
                        Button("Supprimer cette ligne", role: .destructive) {
                            match.rounds.removeAll { $0.id == round.id }
                        }
                    }
                } header: {
                    Text(game.id == "the-crew" ? "Mission \(index + 1)" : "Manche \(index + 1)")
                }
            }

            Button {
                match.rounds.append(CatalogRound())
            } label: {
                Label(game.id == "the-crew" ? "Ajouter une mission" : "Ajouter une manche", systemImage: "plus")
            }
            .disabled(match.rounds.last?.entries.isEmpty == true || match.rounds.count >= 500)
        }
        .navigationTitle(game.title)
        .toolbar {
            Menu {
                Button("Nouvelle partie", systemImage: "arrow.counterclockwise", role: .destructive) {
                    confirmReset = true
                }
            } label: {
                Label("Options", systemImage: "ellipsis.circle")
            }
        }
        .confirmationDialog("Effacer les scores de cette partie ?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Nouvelle partie", role: .destructive) {
                match = CatalogMatch(players: roster)
            }
        }
        .sheet(item: $selectedCell) { cell in
            ScoreEntryView(title: cell.player.name, fields: game.fields, values: cell.values) { values in
                guard let index = match.rounds.firstIndex(where: { $0.id == cell.roundID }) else { return }
                match.rounds[index].entries[cell.player.id] = values
            }
        }
        .onChange(of: match) {
            do { saved = try JSONEncoder().encode(match) }
            catch { storageError = true }
        }
        .alert("La sauvegarde a échoué", isPresented: $storageError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Les scores sont encore affichés. Réessayez après une modification.")
        }
    }

    private var rankedPlayers: [Player] {
        match.players.sorted { first, second in
            if game.rule == .phase {
                let firstPhases = match.phases(for: first)
                let secondPhases = match.phases(for: second)
                if firstPhases != secondPhases { return firstPhases > secondPhases }
            }
            let firstScore = match.total(for: first, game: game)
            let secondScore = match.total(for: second, game: game)
            if firstScore == secondScore && game.rule == .encore {
                return encoreJokers(for: first) > encoreJokers(for: second)
            }
            return game.rule.lowestWins || game.rule == .phase ? firstScore < secondScore : firstScore > secondScore
        }
    }

    private func encoreJokers(for player: Player) -> Int {
        match.rounds.compactMap { $0.entries[player.id]?.last }.reduce(0, +)
    }

    private struct Cell: Identifiable {
        let id = UUID()
        let roundID: UUID
        let player: Player
        let values: [Int]?
    }
}

private struct ScoreEntryView: View {
    let title: String
    let fields: [ScoreField]
    let hadEntry: Bool
    let onSave: ([Int]?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var input: [String]

    init(title: String, fields: [ScoreField], values: [Int]?, onSave: @escaping ([Int]?) -> Void) {
        self.title = title
        self.fields = fields
        hadEntry = values != nil
        self.onSave = onSave
        _input = State(initialValue: fields.indices.map { index in
            guard let values, values.indices.contains(index) else { return "" }
            return String(values[index])
        })
    }

    var body: some View {
        NavigationStack {
            Form {
                ForEach(fields.indices, id: \.self) { index in
                    let field = fields[index]
                    if field.range == 0...1 {
                        Toggle(field.label.replacingOccurrences(of: " (0 ou 1)", with: ""), isOn: Binding(
                            get: { input[index] == "1" },
                            set: { input[index] = $0 ? "1" : "0" }
                        ))
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            TextField(field.label, text: $input[index], prompt: Text(String(max(0, field.range.lowerBound))))
                                .keyboardType(field.range.lowerBound < 0 ? .numbersAndPunctuation : .numberPad)
                            if !input[index].isEmpty && value(at: index) == nil {
                                Text("Saisissez une valeur entre \(field.range.lowerBound) et \(field.range.upperBound).")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
                if hadEntry {
                    Button("Effacer cette saisie", role: .destructive) {
                        onSave(nil)
                        dismiss()
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        onSave(fields.indices.compactMap { value(at: $0) })
                        dismiss()
                    }
                    .disabled(fields.indices.contains { value(at: $0) == nil })
                }
            }
        }
    }

    private func value(at index: Int) -> Int? {
        let range = fields[index].range
        let fallback = max(0, range.lowerBound)
        let normalized = input[index].trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "−", with: "-")
        guard let value = normalized.isEmpty ? fallback : Int(normalized), range.contains(value) else { return nil }
        return value
    }
}
