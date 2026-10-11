import SwiftUI
import Foundation

// MARK: - App Screen Navigation
enum AppScreen: Hashable {
    case fingerPick
    case gameSelection
    case yams
    case skullKing
    case basicScoreSheet
}

// MARK: - Player Model
struct Player: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var colorHex: String
    
    init(id: UUID = UUID(), name: String, colorHex: String) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }
    
    var color: Color {
        Color(hex: colorHex)
    }
}

// MARK: - Tap Marker for Finger Picker
struct TapMarker: Identifiable, Equatable {
    let id: Int
    var location: CGPoint
    let color: Color
    let colorHex: String
    let playerNumber: Int
    let createdAt: Date = Date()
}

// MARK: - Color Palette
struct AppPalette {
    static let colors: [(name: String, hex: String)] = [
        ("Cyan", "#0ED4F9"),
        ("Or", "#FFB52E"),
        ("Corail", "#FF4757"),
        ("Lime", "#7BED34"),
        ("Violet", "#B873FF"),
        ("Bleu Royal", "#2980B9"),
        ("Rose Vif", "#FF6B8B"),
        ("Émeraude", "#2ED573"),
        ("Orange", "#FFA502"),
        ("Pourpre", "#9B59B6"),
        ("Turquoise", "#1ABC9C"),
        ("Jaune Soleil", "#F1C40F"),
        ("Framboise", "#E84393"),
        ("Bleu Ciel", "#70A1FF"),
        ("Menthe", "#55E6C1"),
        ("Ambre", "#E67E22"),
        ("Indigo", "#575FCF"),
        ("Rouge Rubis", "#D63031"),
        ("Vert Pomme", "#A3CB38"),
        ("Lavande", "#D980FA"),
        ("Saphir", "#1B9CFC"),
        ("Pêche", "#F8A5C2"),
        ("Topaze", "#F39C12"),
        ("Jade", "#00B894")
    ]
    
    static func color(at index: Int) -> Color {
        let hex = colors[index % colors.count].hex
        return Color(hex: hex)
    }
    
    static func hex(at index: Int) -> String {
        return colors[index % colors.count].hex
    }
}

// MARK: - Yams Models
enum YamsSection: String, CaseIterable {
    case upper = "Section Supérieure"
    case lower = "Section Inférieure"
}

enum YamsCategory: String, CaseIterable, Identifiable {
    case ones = "As (1)"
    case twos = "Deux (2)"
    case threes = "Trois (3)"
    case fours = "Quatre (4)"
    case fives = "Cinq (5)"
    case sixes = "Six (6)"
    
    case threeOfAKind = "Brelan"
    case fourOfAKind = "Carré"
    case fullHouse = "Full (25)"
    case smallStraight = "Petite Suite (30)"
    case largeStraight = "Grande Suite (40)"
    case yahtzee = "Yams (50)"
    case chance = "Chance"
    
    var id: String { rawValue }
    
    var section: YamsSection {
        switch self {
        case .ones, .twos, .threes, .fours, .fives, .sixes:
            return .upper
        case .threeOfAKind, .fourOfAKind, .fullHouse, .smallStraight, .largeStraight, .yahtzee, .chance:
            return .lower
        }
    }
    
    var subtitle: String {
        switch self {
        case .ones: return "Total des 1"
        case .twos: return "Total des 2"
        case .threes: return "Total des 3"
        case .fours: return "Total des 4"
        case .fives: return "Total des 5"
        case .sixes: return "Total des 6"
        case .threeOfAKind: return "Somme des 5 dés (3 identiques)"
        case .fourOfAKind: return "Somme des 5 dés (4 identiques)"
        case .fullHouse: return "3 identiques + 2 identiques = 25 pts"
        case .smallStraight: return "4 dés consécutifs = 30 pts"
        case .largeStraight: return "5 dés consécutifs = 40 pts"
        case .yahtzee: return "5 dés identiques = 50 pts"
        case .chance: return "Somme libre des 5 dés"
        }
    }
    
    var fixedValue: Int? {
        switch self {
        case .fullHouse: return 25
        case .smallStraight: return 30
        case .largeStraight: return 40
        case .yahtzee: return 50
        default: return nil
        }
    }
    
    var diceValue: Int? {
        switch self {
        case .ones: return 1
        case .twos: return 2
        case .threes: return 3
        case .fours: return 4
        case .fives: return 5
        case .sixes: return 6
        default: return nil
        }
    }
}

struct YamsPlayerSheet: Equatable {
    var scores: [YamsCategory: Int] = [:]
    
    var upperTotal: Int {
        let upperCategories: [YamsCategory] = [.ones, .twos, .threes, .fours, .fives, .sixes]
        return upperCategories.compactMap { scores[$0] }.reduce(0, +)
    }
    
    var upperBonus: Int {
        upperTotal >= 63 ? 35 : 0
    }
    
    /// Écart par rapport à la moyenne de 3 dés par catégorie (63 pts au total)
    var upperDelta: Int {
        upperTotal - 63
    }
    
    var totalUpperWithBonus: Int {
        upperTotal + upperBonus
    }
    
    var lowerTotal: Int {
        let lowerCategories: [YamsCategory] = [
            .threeOfAKind, .fourOfAKind, .fullHouse,
            .smallStraight, .largeStraight, .yahtzee, .chance
        ]
        return lowerCategories.compactMap { scores[$0] }.reduce(0, +)
    }
    
    var grandTotal: Int {
        totalUpperWithBonus + lowerTotal
    }
    
    var completedCount: Int {
        scores.count
    }
    
    var isComplete: Bool {
        scores.count == YamsCategory.allCases.count
    }
}

// MARK: - Skull King Models
struct SkullKingRoundData: Equatable {
    var bet: Int? = nil       // Pari (de 0 à roundNumber)
    var tricks: Int? = nil    // Plis réalisés (de 0 à roundNumber)
    var bonus: Int = 0        // Points bonus (butin +20, cartes 14 +10/+20, pirates +30, sirènes...)
    var krakenPlayed: Bool = false // Kraken dévore le pli (1 pli détruit)
    
    func score(for roundNumber: Int) -> Int? {
        guard let bet = bet, let tricks = tricks else { return nil }
        
        if bet == 0 {
            // Pari Zéro
            if tricks == 0 {
                return (roundNumber * 10) + bonus
            } else {
                return -(roundNumber * 10)
            }
        } else {
            // Pari normal (> 0)
            if tricks == bet {
                return (bet * 20) + bonus
            } else {
                let diff = abs(tricks - bet)
                return -(diff * 10)
            }
        }
    }
}

struct SkullKingPlayerSheet: Equatable {
    // Manches (par défaut 10, mais ajustable à 8, 9 ou custom selon variantes et joueurs)
    var rounds: [Int: SkullKingRoundData] = [:]
    
    init(totalRounds: Int = 10) {
        for round in 1...max(1, totalRounds) {
            rounds[round] = SkullKingRoundData()
        }
    }
    
    func roundScore(for roundNumber: Int) -> Int? {
        rounds[roundNumber]?.score(for: roundNumber)
    }
    
    func totalScore(upTo maxRound: Int = 10) -> Int {
        (1...maxRound).compactMap { roundScore(for: $0) }.reduce(0, +)
    }
    
    var totalScore: Int {
        rounds.keys.sorted().compactMap { roundScore(for: $0) }.reduce(0, +)
    }
}

// MARK: - Basic Game Models
struct BasicRound: Identifiable, Equatable {
    let id: UUID = UUID()
    var number: Int
    var scores: [UUID: Int] = [:] // Player ID -> score for this round
}

// MARK: - Color Hex Extensions
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 128, 128, 128)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
