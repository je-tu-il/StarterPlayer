import Foundation

enum DrawMode: String, CaseIterable, Hashable, Codable {
    case touch = "Tactile"
    case voice = "Vocal"
    case random = "Aléatoire"
    case wheel = "Roue"
    case dice = "Dés"
    case cards = "Cartes"
    case teams = "Équipes"
    case order = "Ordre de passage"
    case rotation = "Rotation par manche"
    case fair = "Tirage équitable"

    static var selectable: [Self] { allCases.filter { $0 != .touch && $0 != .voice } }

    var instructions: String {
        switch self {
        case .touch, .voice: ""
        case .random: "Chaque joueur a la même chance de commencer."
        case .wheel: "Le joueur sous le repère commence."
        case .dice: "Le plus grand dé commence. Les joueurs à égalité relancent."
        case .cards: "L’as est la carte la plus forte. À valeur égale : pique, cœur, carreau, trèfle."
        case .teams: "Répartition au hasard, avec au plus un joueur d’écart entre les équipes."
        case .order: "Mélangez la liste pour obtenir un ordre complet."
        case .rotation: "Gardez votre ordre de table. Le premier joueur change à chaque lancement."
        case .fair: "Donne la priorité aux joueurs qui ont le moins souvent commencé dans l’historique."
        }
    }
}

struct DrawRecord: Identifiable, Codable, Equatable {
    var id = UUID()
    var date = Date()
    let mode: DrawMode
    let roster: [UUID]
    var winner: UUID?
    var lines: [String]
}

enum DrawEngine {
    static func generate<R: RandomNumberGenerator>(
        mode: DrawMode, roster: [Player], history: [DrawRecord], teamCount: Int, using generator: inout R
    ) -> DrawRecord? {
        guard (2...52).contains(roster.count) else { return nil }
        let ids = roster.map(\.id)
        var result = DrawRecord(mode: mode, roster: ids, lines: [])

        switch mode {
        case .touch, .voice: return nil
        case .random, .wheel:
            result.winner = ids.randomElement(using: &generator)
        case .fair:
            let wins = Dictionary(grouping: history.compactMap(\.winner), by: { $0 }).mapValues(\.count)
            let minimum = ids.map { wins[$0, default: 0] }.min() ?? 0
            result.winner = ids.filter { wins[$0, default: 0] == minimum }.randomElement(using: &generator)
        case .dice:
            var candidates = roster
            var rolls: [UUID: [Int]] = [:]
            while candidates.count > 1 {
                for player in candidates {
                    rolls[player.id, default: []].append(Int.random(in: 1...6, using: &generator))
                }
                let best = candidates.compactMap { rolls[$0.id]?.last }.max()
                candidates = candidates.filter { rolls[$0.id]?.last == best }
            }
            result.winner = candidates.first?.id
            result.lines = roster.map { player in
                "\(player.name) · " + (rolls[player.id] ?? []).map(String.init).joined(separator: " → ")
            }
        case .cards:
            let deck = (0..<52).shuffled(using: &generator)
            let cards = Array(zip(roster, deck))
            let ranks = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "V", "D", "R", "A"]
            let suits = ["Trèfle", "Carreau", "Cœur", "Pique"]
            result.winner = cards.max { $0.1 < $1.1 }?.0.id
            result.lines = cards.map { player, card in
                "\(player.name) · \(ranks[card / 4]) · \(suits[card % 4])"
            }
        case .teams:
            let count = min(max(2, teamCount), roster.count)
            let shuffled = roster.shuffled(using: &generator)
            result.lines = (0..<count).map { index in
                let members = stride(from: index, to: shuffled.count, by: count).map { shuffled[$0].name }
                return "Équipe \(index + 1) · " + members.joined(separator: ", ")
            }
        case .order:
            let order = roster.shuffled(using: &generator)
            result.winner = order.first?.id
            result.lines = numbered(order)
        case .rotation:
            let previous = history.first { $0.mode == .rotation && $0.roster == ids }
            let start = previous?.winner.flatMap { ids.firstIndex(of: $0) }.map { ($0 + 1) % ids.count } ?? 0
            let order = Array(roster[start...] + roster[..<start])
            result.winner = order.first?.id
            result.lines = numbered(order)
        }

        if let winner = roster.first(where: { $0.id == result.winner }) {
            result.lines.insert("Commence : \(winner.name)", at: 0)
        }
        return result
    }

    private static func numbered(_ players: [Player]) -> [String] {
        players.enumerated().map { "\($0.offset + 1). \($0.element.name)" }
    }
}


enum DrawHistory {
    static func read(_ data: Data) -> [DrawRecord] {
        (try? JSONDecoder().decode([DrawRecord].self, from: data)) ?? []
    }

    static func appending(_ record: DrawRecord, to data: Data) -> Data {
        let updated = [record] + Array(read(data).prefix(199))
        return (try? JSONEncoder().encode(updated)) ?? data
    }
}
