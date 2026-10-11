import Testing
@testable import FingerPick

struct FingerPickTests {

    @Test func testYamsBonusThreshold() async throws {
        var sheet = YamsPlayerSheet()
        // 3 of each in upper section: 3 + 6 + 9 + 12 + 15 + 18 = 63 points
        sheet.scores[.ones] = 3
        sheet.scores[.twos] = 6
        sheet.scores[.threes] = 9
        sheet.scores[.fours] = 12
        sheet.scores[.fives] = 15
        sheet.scores[.sixes] = 18
        
        #expect(sheet.upperTotal == 63)
        #expect(sheet.upperBonus == 35)
        #expect(sheet.upperDelta == 0)
        #expect(sheet.totalUpperWithBonus == 98)
    }

    @Test func testYamsWithoutBonus() async throws {
        var sheet = YamsPlayerSheet()
        // 62 points: 1 short of 63
        sheet.scores[.ones] = 3
        sheet.scores[.twos] = 6
        sheet.scores[.threes] = 9
        sheet.scores[.fours] = 12
        sheet.scores[.fives] = 15
        sheet.scores[.sixes] = 17
        
        #expect(sheet.upperTotal == 62)
        #expect(sheet.upperBonus == 0)
        #expect(sheet.upperDelta == -1)
        #expect(sheet.totalUpperWithBonus == 62)
    }

    @Test func testYamsGrandTotal() async throws {
        var sheet = YamsPlayerSheet()
        sheet.scores[.ones] = 3
        sheet.scores[.fullHouse] = 25
        sheet.scores[.yahtzee] = 50
        sheet.scores[.chance] = 24
        
        #expect(sheet.upperTotal == 3)
        #expect(sheet.lowerTotal == 99)
        #expect(sheet.grandTotal == 102)
    }

    @Test func testSkullKingSuccessfulBet() async throws {
        let round1 = SkullKingRoundData(bet: 1, tricks: 1, bonus: 20)
        #expect(round1.score(for: 1) == 40) // 1 * 20 + 20
        
        let round5 = SkullKingRoundData(bet: 3, tricks: 3, bonus: 10)
        #expect(round5.score(for: 5) == 70) // 3 * 20 + 10
    }

    @Test func testSkullKingMissedBet() async throws {
        // Bet 3, got 1 -> diff of 2 -> -20 pts
        let round4 = SkullKingRoundData(bet: 3, tricks: 1, bonus: 0)
        #expect(round4.score(for: 4) == -20)
        
        // Bet 1, got 3 -> diff of 2 -> -20 pts
        let round5 = SkullKingRoundData(bet: 1, tricks: 3, bonus: 10)
        #expect(round5.score(for: 5) == -20)
    }

    @Test func testSkullKingZeroBetSuccess() async throws {
        // Round 1 zero bet successful: +10 pts
        let r1 = SkullKingRoundData(bet: 0, tricks: 0, bonus: 0)
        #expect(r1.score(for: 1) == 10)
        
        // Round 7 zero bet successful with pirate bonus: +70 + 30 = +100 pts
        let r7 = SkullKingRoundData(bet: 0, tricks: 0, bonus: 30)
        #expect(r7.score(for: 7) == 100)
    }

    @Test func testSkullKingZeroBetFailed() async throws {
        // Round 1 zero bet failed: -10 pts
        let r1 = SkullKingRoundData(bet: 0, tricks: 1, bonus: 0)
        #expect(r1.score(for: 1) == -10)
        
        // Round 10 zero bet failed: -100 pts
        let r10 = SkullKingRoundData(bet: 0, tricks: 1, bonus: 0)
        #expect(r10.score(for: 10) == -100)
    }

    @Test func testSkullKingButinBonus() async throws {
        // Round 3, bet 2, tricks 2, with Butin bonus (+20 pts)
        let r3 = SkullKingRoundData(bet: 2, tricks: 2, bonus: 20)
        #expect(r3.score(for: 3) == 60) // 2 * 20 + 20
    }

    @Test func testPlayerPaletteUniqueness() async throws {
        #expect(AppPalette.colors.count >= 20)
        let c1 = AppPalette.color(at: 0)
        let c2 = AppPalette.color(at: 1)
        #expect(c1 != c2)
    }
}
