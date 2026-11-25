import Foundation
import SwiftUI

struct GameSelectionView: View {
    @Binding var currentScreen: AppScreen
    @Binding var players: [Player]
    @State private var query = ""
    @State private var newPlayer: Player?

    var body: some View {
        NavigationStack {
            List {
                if filteredGames.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
                ForEach(ScoreCategory.allCases, id: \.self) { category in
                    let games = filteredGames.filter { $0.category == category }
                    if !games.isEmpty {
                        Section(category.rawValue) {
                            ForEach(games) { game in
                                if game.rule == .yams || game.rule == .skull {
                                    Button {
                                        ensurePlayers(minimum: game.rule == .yams ? 1 : 2)
                                        currentScreen = game.rule == .skull ? .skullKing
                                            : (game.id == "yahtzee" ? .yahtzee : .yams)
                                    } label: {
                                        gameLabel(game)
                                    }
                                } else {
                                    NavigationLink {
                                        CatalogScoreView(game: game, players: scorePlayers(for: game))
                                    } label: {
                                        gameLabel(game)
                                    }
                                }
                            }
                        }
                    }
                }
                if query.isEmpty {
                    Section {
                        Button {
                            ensurePlayers()
                            currentScreen = .basicScoreSheet
                        } label: {
                            Label("Feuille libre", systemImage: "square.and.pencil")
                        }
                    }
                }
            }
            .navigationTitle("Scores")
            .searchable(text: $query, prompt: "Rechercher un jeu")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Tirage", systemImage: "chevron.left") { currentScreen = .drawHome }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Ajouter un joueur", systemImage: "person.badge.plus") {
                        newPlayer = Player(name: "", colorHex: AppPalette.hex(at: players.count))
                    }
                }
            }
            .sheet(item: $newPlayer) { player in
                PlayerEditSheet(player: player, onSave: { players.append($0) })
            }
        }
    }

    private var filteredGames: [ScoreGame] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchTerms = text.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        let games = ScoreGame.all.filter { game in
            searchTerms.allSatisfy { term in
                let searchable = (game.title + " " + game.id).filter { $0.isLetter || $0.isNumber }
                return searchable.localizedStandardContains(String(term))
            }
        }
        return games.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private func gameLabel(_ game: ScoreGame) -> some View {
        Label {
            Text(game.title).foregroundStyle(.primary)
        } icon: {
            Image(systemName: game.category.icon)
        }
    }

    private func scorePlayers(for game: ScoreGame) -> [Player] {
        var roster = players
        let teamGames = ["belote", "coinche", "bridge", "canasta", "spades", "euchre", "sueca", "tute", "whist"]
        if teamGames.contains(game.id) {
            return (0..<2).map { index in
                let id = UUID(uuidString: "E9C06B0D-3A02-46A7-BE65-FD815ADFE80\(index)") ?? UUID()
                return Player(id: id, name: "Équipe \(index + 1)", colorHex: AppPalette.hex(at: index))
            }
        }
        let soloGames = ["clever", "double-clever", "triples-clever", "encore", "cartographers"]
        let minimum = soloGames.contains(game.id) ? 1 : 2
        while roster.count < minimum {
            roster.append(Player(name: "Joueur \(roster.count + 1)", colorHex: AppPalette.hex(at: roster.count)))
        }
        return roster
    }

    private func ensurePlayers(minimum: Int = 2) {
        while players.count < minimum {
            players.append(Player(name: "Joueur \(players.count + 1)", colorHex: AppPalette.hex(at: players.count)))
        }
    }
}

struct PlayerEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("fingerpick.voiceNames.v1") private var recentNamesData = Data()
    @State var player: Player
    var onSave: (Player) -> Void
    var onDelete: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Nom") {
                    TextField("Prénom", text: $player.name)
                    ForEach(Array(suggestions.prefix(5)), id: \.self) { suggestion in
                        Button(suggestion) { player.name = suggestion }
                    }
                }
                Section("Couleur") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
                        ForEach(AppPalette.colors, id: \.hex) { item in
                            Button {
                                player.colorHex = item.hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: item.hex))
                                    .overlay {
                                        if player.colorHex == item.hex {
                                            Image(systemName: "checkmark").foregroundStyle(.black)
                                        }
                                    }
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(item.name)
                            .accessibilityAddTraits(player.colorHex == item.hex ? .isSelected : [])
                        }
                    }
                }
                if let onDelete {
                    Button("Supprimer ce joueur", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Modifier le joueur")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        player.name = String(trimmedName.prefix(40))
                        var names = recentNames.filter { $0.caseInsensitiveCompare(player.name) != .orderedSame }
                        names.insert(player.name, at: 0)
                        recentNamesData = (try? JSONEncoder().encode(Array(names.prefix(60)))) ?? recentNamesData
                        onSave(player)
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private var trimmedName: String { player.name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var recentNames: [String] {
        (try? JSONDecoder().decode([String].self, from: recentNamesData)) ?? []
    }

    private var suggestions: [String] {
        guard !trimmedName.isEmpty else { return [] }
        return recentNames.filter {
            $0.caseInsensitiveCompare(trimmedName) != .orderedSame &&
            $0.range(of: trimmedName, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
}
