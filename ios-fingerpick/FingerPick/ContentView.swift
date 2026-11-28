import Foundation
import SwiftUI

struct ContentView: View {
    @AppStorage("fingerpick.roster.v1") private var savedRoster = Data()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentScreen: AppScreen = .voicePick
    @State private var players: [Player] = []

    var body: some View {
        ZStack {
            switch currentScreen {
            case .drawHome:
                DrawHomeView(screen: $currentScreen, players: $players)
            case .voicePick:
                VoiceFirstPlayerView(currentScreen: $currentScreen, gamePlayers: $players)
            case .fingerPick:
                FingerPickerView(currentScreen: $currentScreen, gamePlayers: $players)
            case .gameSelection:
                GameSelectionView(currentScreen: $currentScreen, players: $players)
            case .yams, .yahtzee:
                YamsView(currentScreen: $currentScreen, players: $players, usesYahtzeeBonus: currentScreen == .yahtzee)
                    .id(currentScreen)
            case .skullKing:
                SkullKingView(currentScreen: $currentScreen, players: $players)
            case .basicScoreSheet:
                BasicScoreSheetView(currentScreen: $currentScreen, players: $players)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: currentScreen)
        .onAppear {
            if let roster = try? JSONDecoder().decode([Player].self, from: savedRoster) { players = roster }
        }
        .onChange(of: savedRoster) {
            let restored = (try? JSONDecoder().decode([Player].self, from: savedRoster)) ?? []
            if restored != players { players = restored }
        }
        .onChange(of: players) {
            if let data = try? JSONEncoder().encode(players) { savedRoster = data }
        }
    }
}

#Preview {
    ContentView()
}
