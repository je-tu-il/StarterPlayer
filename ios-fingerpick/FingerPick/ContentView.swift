import SwiftUI

struct ContentView: View {
    @State private var currentScreen: AppScreen = .fingerPick
    @State private var players: [Player] = []

    var body: some View {
        ZStack {
            switch currentScreen {
            case .fingerPick:
                FingerPickerView(currentScreen: $currentScreen, gamePlayers: $players)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96)),
                        removal: .opacity.combined(with: .scale(scale: 1.04))
                    ))
            case .gameSelection:
                GameSelectionView(currentScreen: $currentScreen, players: $players)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            case .yams:
                YamsView(currentScreen: $currentScreen, players: $players)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            case .skullKing:
                SkullKingView(currentScreen: $currentScreen, players: $players)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            case .basicScoreSheet:
                BasicScoreSheetView(currentScreen: $currentScreen, players: $players)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentScreen)
    }
}

#Preview {
    ContentView()
}
