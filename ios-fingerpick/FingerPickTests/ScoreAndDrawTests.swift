import Foundation
import Testing
@testable import FingerPick

@MainActor
struct ScoreAndDrawTests {
    @Test func catalogHasStableUniqueIDs() {
        let games = ScoreGame.all
        #expect(games.count >= 100)
        #expect(Set(games.map(\.id)).count == games.count)
        #expect(Set(games.map(\.title)).count == games.count)
        let requested = [
            "belote", "coinche", "tarot", "rami", "uno", "skyjo", "skyjo-action", "flip7", "take6",
            "president", "phase10", "skull-king", "the-crew", "wizard", "cabo", "trio", "five-crowns",
            "canasta", "cribbage", "bridge", "yams", "yahtzee", "farkle", "421", "qwixx", "clever", "encore"
        ]
        #expect(Set(requested).isSubset(of: Set(games.map(\.id))))
    }

    @Test func flipSevenMultiplierDoesNotDoubleBonuses() throws {
        let game = try game("flip7")
        #expect(game.score([30, 4, 1, 1, 0]) == 79)
        #expect(game.score([30, 4, 1, 1, 1]) == 0)
    }

    @Test func skyjoPositiveTieDoublesButNegativeTieDoesNot() throws {
        let game = try game("skyjo")
        #expect(game.score([10, 1], skyjoMinimum: 10, minimumCount: 2) == 20)
        #expect(game.score([10, 1], skyjoMinimum: 10, minimumCount: 1) == 10)
        #expect(game.score([-1, 1], skyjoMinimum: -1, minimumCount: 2) == -1)
    }

    @Test func wizardScoresExactAndMissedBids() throws {
        let game = try game("wizard")
        #expect(game.score([0, 0]) == 20)
        #expect(game.score([3, 3]) == 50)
        #expect(game.score([3, 1]) == -20)
    }

    @Test func diceSheetsApplyTheirBonusesAndPenalties() throws {
        let qwixx = try game("qwixx")
        let clever = try game("clever")
        let encore = try game("encore")
        #expect(qwixx.score([12, 3, 2, 1, 4]) == 68)
        #expect(clever.score([3, 7, 12, 10, 2, 3]) == 40)
        #expect(encore.score([13, 5, 4, 2]) == 12)
    }

    @Test func savedScoresRoundTripWithTheSamePlayerAndRoundIDs() throws {
        let game = try game("wizard")
        let players = makePlayers(2)
        var match = CatalogMatch(players: players)
        match.rounds[0].entries[players[0].id] = [2, 2]
        let data = try JSONEncoder().encode(match)
        let restored = try JSONDecoder().decode(CatalogMatch.self, from: data)
        #expect(restored == match)
        #expect(restored.total(for: players[0], game: game) == 40)
    }

    @Test func fairDrawPrefersThePersonWhoHasNeverStarted() throws {
        let roster = makePlayers(3)
        let ids = roster.map(\.id)
        let history = ids.prefix(2).map { DrawRecord(mode: .random, roster: ids, winner: $0, lines: []) }
        var rng = SystemRandomNumberGenerator()
        let result = try #require(DrawEngine.generate(mode: .fair, roster: roster, history: history,
                                                     teamCount: 2, using: &rng))
        #expect(result.winner == ids[2])
    }

    @Test func rotationFollowsRosterAndWraps() throws {
        let roster = makePlayers(3)
        var history: [DrawRecord] = []
        var rng = SystemRandomNumberGenerator()
        for index in 0..<7 {
            let result = try #require(DrawEngine.generate(mode: .rotation, roster: roster, history: history,
                                                         teamCount: 2, using: &rng))
            #expect(result.winner == roster[index % roster.count].id)
            history.insert(result, at: 0)
        }
    }

    @Test func cardDrawDealsDistinctCardsAndChoosesAPlayer() throws {
        let roster = makePlayers(24)
        var rng = SystemRandomNumberGenerator()
        let result = try #require(DrawEngine.generate(mode: .cards, roster: roster, history: [],
                                                     teamCount: 2, using: &rng))
        let cards = result.lines.dropFirst().map { $0.components(separatedBy: " · ").dropFirst().joined() }
        #expect(Set(cards).count == 24)
        #expect(roster.contains { $0.id == result.winner })
    }

    @Test func teamsDifferByAtMostOne() throws {
        let roster = makePlayers(7)
        var rng = SystemRandomNumberGenerator()
        let result = try #require(DrawEngine.generate(mode: .teams, roster: roster, history: [],
                                                     teamCount: 3, using: &rng))
        let sizes = result.lines.map { $0.components(separatedBy: ", ").count }.sorted()
        #expect(sizes == [2, 2, 3])
        #expect(result.winner == nil)
    }

    private func game(_ id: String) throws -> ScoreGame {
        try #require(ScoreGame.all.first { $0.id == id })
    }

    private func makePlayers(_ count: Int) -> [Player] {
        (0..<count).map { Player(name: "Joueur \($0)", colorHex: AppPalette.hex(at: $0)) }
    }
}
