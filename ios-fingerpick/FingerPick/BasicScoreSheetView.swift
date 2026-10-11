import SwiftUI
import UIKit

struct BasicScoreSheetView: View {
    @Binding var currentScreen: AppScreen
    @Binding var players: [Player]
    
    @State private var rounds: [BasicRound] = []
    @State private var selectedCell: BasicCellItem? = nil
    @State private var scoreInputText: String = ""
    @State private var isLowestScoreWins: Bool = false
    @State private var showingResetAlert: Bool = false
    @State private var showingLeaderboard: Bool = false
    
    private let hapticImpact = UIImpactFeedbackGenerator(style: .medium)
    private let hapticSuccess = UINotificationFeedbackGenerator()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.06, blue: 0.12).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Option Bar (Win Condition & Stats)
                    topOptionBar
                    
                    // Main Score Table
                    ScrollView([.vertical, .horizontal], showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 0) {
                            // Table Header Row
                            HStack(spacing: 0) {
                                Text("MANCHE")
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.45))
                                    .padding(.horizontal, 10)
                                    .frame(width: 86, height: 48)
                                    .background(Color(red: 0.08, green: 0.10, blue: 0.18))
                                
                                ForEach(players) { player in
                                    VStack(spacing: 2) {
                                        Circle().fill(player.color).frame(width: 10, height: 10)
                                        Text(player.name)
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 80, height: 48)
                                    .background(Color(red: 0.08, green: 0.10, blue: 0.18))
                                }
                                
                                // Add Player Quick Button
                                Button {
                                    addNewPlayer()
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.cyan.opacity(0.8))
                                        .frame(width: 44, height: 48)
                                }
                            }
                            
                            Divider().background(Color.white.opacity(0.12))
                            
                            // Rounds Rows
                            ForEach(rounds) { round in
                                HStack(spacing: 0) {
                                    // Sticky Round Label
                                    Text("M\(round.number)")
                                        .font(.system(size: 14, weight: .black, design: .rounded))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .frame(width: 86, height: 44, alignment: .leading)
                                        .background(Color(red: 0.08, green: 0.10, blue: 0.18))
                                    
                                    ForEach(players) { player in
                                        let score = round.scores[player.id]
                                        
                                        Button {
                                            hapticImpact.impactOccurred()
                                            scoreInputText = score.map { "\($0)" } ?? ""
                                            selectedCell = BasicCellItem(roundID: round.id, player: player)
                                        } label: {
                                            ZStack {
                                                if let score = score {
                                                    Text("\(score)")
                                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                                        .foregroundStyle(.white)
                                                } else {
                                                    Circle()
                                                        .fill(Color.white.opacity(0.10))
                                                        .frame(width: 6, height: 6)
                                                }
                                            }
                                            .frame(width: 80, height: 44)
                                            .background(Color.white.opacity(0.02))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .overlay(Rectangle().frame(height: 0.5).foregroundStyle(Color.white.opacity(0.06)), alignment: .bottom)
                            }
                            
                            Divider().background(Color.white.opacity(0.2))
                            
                            // Total Row
                            HStack(spacing: 0) {
                                Text("TOTAL")
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .foregroundStyle(.cyan)
                                    .padding(.horizontal, 10)
                                    .frame(width: 86, height: 50, alignment: .leading)
                                    .background(Color(red: 0.10, green: 0.12, blue: 0.22))
                                
                                ForEach(players) { player in
                                    let total = totalScore(for: player)
                                    VStack(spacing: 1) {
                                        Text("\(total)")
                                            .font(.system(size: 16, weight: .black, design: .rounded))
                                            .foregroundStyle(.cyan)
                                        
                                        if let rank = rankText(for: player) {
                                            Text(rank)
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(.white.opacity(0.5))
                                        }
                                    }
                                    .frame(width: 80, height: 50)
                                    .background(Color.cyan.opacity(0.08))
                                }
                            }
                        }
                        .padding(.bottom, 80)
                    }
                }
                
                // Floating "+ Ajouter une manche" button
                VStack {
                    Spacer()
                    Button {
                        addNewRound()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18, weight: .bold))
                            Text("Ajouter la manche \(rounds.count + 1)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 22)
                        .frame(height: 48)
                        .background(Capsule().fill(Color.cyan))
                        .shadow(color: .cyan.opacity(0.4), radius: 12, y: 4)
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Feuille Basique")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.spring()) {
                            currentScreen = .gameSelection
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Jeux")
                        }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.cyan)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showingLeaderboard = true
                        } label: {
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(.yellow)
                        }
                        
                        Button {
                            showingResetAlert = true
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
            }
            .alert("Nouvelle feuille ?", isPresented: $showingResetAlert) {
                Button("Annuler", role: .cancel) {}
                Button("Recommencer", role: .destructive) {
                    resetGame()
                }
            } message: {
                Text("Toutes les manches seront effacées.")
            }
            .sheet(item: $selectedCell) { item in
                ZStack {
                    Color(red: 0.08, green: 0.10, blue: 0.16).ignoresSafeArea()
                    
                    VStack(spacing: 14) {
                        let roundNum = rounds.first(where: { $0.id == item.roundID })?.number ?? 1
                        
                        // Dedicated numeric keypad with auto-advance
                        NumericKeypadView(
                            textValue: $scoreInputText,
                            title: item.player.name,
                            subtitle: "Manche \(roundNum)",
                            allowNegative: true,
                            quickPresets: [-10, -5, 0, 5, 10, 20, 50, 100],
                            onValidate: { score in
                                applyScoreAndAdvance(roundID: item.roundID, player: item.player, score: score)
                            },
                            onCancel: {
                                selectedCell = nil
                            }
                        )
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 16)
                }
                .presentationDetents([.fraction(0.68)])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingLeaderboard) {
                BasicLeaderboardSheet(players: players, rounds: rounds, lowestWins: isLowestScoreWins)
            }
            .onAppear {
                if rounds.isEmpty {
                    addNewRound()
                }
            }
        }
    }
    
    // MARK: - Top Option Bar
    private var topOptionBar: some View {
        HStack {
            Button {
                withAnimation { isLowestScoreWins.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isLowestScoreWins ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .foregroundStyle(isLowestScoreWins ? .orange : .cyan)
                    Text(isLowestScoreWins ? "Plus petit score gagne (Skyjo...)" : "Plus grand score gagne (Tarot...)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.08)))
            }
            
            Spacer()
            
            Text("\(rounds.count) manche\(rounds.count > 1 ? "s" : "")")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(red: 0.08, green: 0.10, blue: 0.18))
    }
    
    // MARK: - Auto-Advance
    private func applyScoreAndAdvance(roundID: UUID, player: Player, score: Int) {
        guard let roundIdx = rounds.firstIndex(where: { $0.id == roundID }) else { return }
        
        rounds[roundIdx].scores[player.id] = score
        hapticSuccess.notificationOccurred(.success)
        
        // Find next player in line
        if let playerIdx = players.firstIndex(where: { $0.id == player.id }) {
            let nextPlayerIdx = playerIdx + 1
            if nextPlayerIdx < players.count {
                // Advance to next player in same round
                let nextPlayer = players[nextPlayerIdx]
                scoreInputText = rounds[roundIdx].scores[nextPlayer.id].map { "\($0)" } ?? ""
                selectedCell = BasicCellItem(roundID: roundID, player: nextPlayer)
            } else {
                // Done with all players for this round
                selectedCell = nil
            }
        } else {
            selectedCell = nil
        }
    }
    
    // MARK: - Helpers
    private func addNewRound() {
        hapticImpact.impactOccurred()
        withAnimation(.spring()) {
            let newRound = BasicRound(number: rounds.count + 1)
            rounds.append(newRound)
        }
    }
    
    private func addNewPlayer() {
        let newIdx = players.count + 1
        let newPlayer = Player(name: "Joueur \(newIdx)", colorHex: AppPalette.hex(at: players.count))
        players.append(newPlayer)
    }
    
    private func totalScore(for player: Player) -> Int {
        rounds.compactMap { $0.scores[player.id] }.reduce(0, +)
    }
    
    private func rankText(for player: Player) -> String? {
        let sorted = players.sorted {
            if isLowestScoreWins {
                return totalScore(for: $0) < totalScore(for: $1)
            } else {
                return totalScore(for: $0) > totalScore(for: $1)
            }
        }
        guard let idx = sorted.firstIndex(where: { $0.id == player.id }) else { return nil }
        switch idx {
        case 0: return "🥇 1er"
        case 1: return "🥈 2e"
        case 2: return "🥉 3e"
        default: return "\(idx + 1)e"
        }
    }
    
    private func resetGame() {
        rounds = [BasicRound(number: 1)]
    }
}

// MARK: - Basic Cell Item for Sheet
struct BasicCellItem: Identifiable {
    let id = UUID()
    let roundID: UUID
    let player: Player
}

// MARK: - Basic Leaderboard
struct BasicLeaderboardSheet: View {
    let players: [Player]
    let rounds: [BasicRound]
    let lowestWins: Bool
    @Environment(\.dismiss) private var dismiss
    
    private func totalScore(for player: Player) -> Int {
        rounds.compactMap { $0.scores[player.id] }.reduce(0, +)
    }
    
    var sortedPlayers: [(player: Player, score: Int)] {
        players.map { ($0, totalScore(for: $0)) }
            .sorted { lowestWins ? $0.score < $1.score : $0.score > $1.score }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.08, green: 0.10, blue: 0.16).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(Array(sortedPlayers.enumerated()), id: \.element.player.id) { index, item in
                            HStack(spacing: 14) {
                                Text(medalOrRank(index))
                                    .font(.system(size: 22, weight: .black))
                                    .frame(width: 36)
                                
                                Circle().fill(item.player.color).frame(width: 28, height: 28)
                                
                                Text(item.player.name)
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                
                                Spacer()
                                
                                Text("\(item.score) pts")
                                    .font(.system(size: 22, weight: .black, design: .rounded))
                                    .foregroundStyle(.cyan)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(index == 0 ? Color.yellow.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1.5)
                                    )
                            )
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Classement Général")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }.foregroundStyle(.cyan)
                }
            }
        }
    }
    
    private func medalOrRank(_ index: Int) -> String {
        switch index {
        case 0: return "🥇"
        case 1: return "🥈"
        case 2: return "🥉"
        default: return "\(index + 1)e"
        }
    }
}
