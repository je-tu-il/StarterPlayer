import SwiftUI
import UIKit

struct SkullKingView: View {
    @Binding var currentScreen: AppScreen
    @Binding var players: [Player]
    
    @State private var sheets: [UUID: SkullKingPlayerSheet] = [:]
    @State private var currentRound: Int = 1
    @State private var totalRounds: Int = 10
    @State private var krakenPlayedInRound: [Int: Bool] = [:]
    @State private var selectedPlayerForDetail: SKDetailItem? = nil
    @State private var showingResetAlert: Bool = false
    @State private var showingLeaderboard: Bool = false
    @State private var viewMode: SkullKingViewMode = .roundWizard // .roundWizard or .fullTable
    
    // For Round Wizard active turn
    @State private var wizardPlayerIndex: Int = 0
    @State private var wizardPhase: SkullKingPhase = .bets // .bets or .results
    
    private let hapticImpact = UIImpactFeedbackGenerator(style: .medium)
    private let hapticSuccess = UINotificationFeedbackGenerator()
    
    enum SkullKingViewMode: String, CaseIterable {
        case roundWizard = "Manche par Manche"
        case fullTable = "Tableau Complet"
    }
    
    enum SkullKingPhase: String {
        case bets = "Paris (Annonces)"
        case results = "Résultats (Plis & Bonus)"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.06, blue: 0.12).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Mode Selector Pill
                    modeSelectorBar
                    
                    if viewMode == .roundWizard {
                        roundWizardView
                    } else {
                        fullTableView
                    }
                }
            }
            .navigationTitle("Skull King")
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
                    HStack(spacing: 10) {
                        Menu {
                            Section("Nombre total de manches") {
                                ForEach([7, 8, 9, 10], id: \.self) { n in
                                    Button {
                                        totalRounds = n
                                        if currentRound > n { currentRound = n }
                                    } label: {
                                        HStack {
                                            Text("\(n) manches")
                                            if totalRounds == n {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 2) {
                                Text("\(totalRounds)M")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundStyle(.cyan)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.cyan.opacity(0.16)))
                        }
                        
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
            .alert("Nouvelle partie de Skull King ?", isPresented: $showingResetAlert) {
                Button("Annuler", role: .cancel) {}
                Button("Recommencer", role: .destructive) {
                    resetGame()
                }
            } message: {
                Text("Toutes les 10 manches seront remises à zéro.")
            }
            .sheet(item: $selectedPlayerForDetail) { item in
                SkullKingDetailModal(
                    player: item.player,
                    round: item.round,
                    data: sheets[item.player.id]?.rounds[item.round] ?? SkullKingRoundData(),
                    onSave: { updated in
                        sheets[item.player.id]?.rounds[item.round] = updated
                        selectedPlayerForDetail = nil
                    }
                )
                .presentationDetents([.medium, .fraction(0.72)])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingLeaderboard) {
                SkullKingLeaderboardSheet(players: players, sheets: sheets)
            }
            .onAppear {
                initializeSheetsIfNeeded()
            }
        }
    }
    
    // MARK: - Mode Selector Bar
    private var modeSelectorBar: some View {
        HStack {
            Picker("Affichage", selection: $viewMode) {
                ForEach(SkullKingViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(red: 0.08, green: 0.10, blue: 0.18))
    }
    
    // MARK: - Wizard View (Round by Round)
    private var roundWizardView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Round Header Card
                VStack(spacing: 8) {
                    HStack {
                        Button {
                            if currentRound > 1 {
                                withAnimation { currentRound -= 1 }
                            }
                        } label: {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(currentRound > 1 ? Color.cyan : Color.white.opacity(0.15))
                        }
                        .disabled(currentRound <= 1)
                        
                        Spacer()
                        
                        VStack(spacing: 2) {
                            Text("MANCHE \(currentRound) / \(totalRounds)")
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            
                            Text("\(currentRound) carte\(currentRound > 1 ? "s" : "") distribuée\(currentRound > 1 ? "s" : "")")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.cyan)
                        }
                        
                        Spacer()
                        
                        Button {
                            if currentRound < totalRounds {
                                withAnimation { currentRound += 1 }
                            }
                        } label: {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(currentRound < totalRounds ? Color.cyan : Color.white.opacity(0.15))
                        }
                        .disabled(currentRound >= totalRounds)
                    }
                    
                    // Kraken toggle button & Phase selector
                    HStack(spacing: 8) {
                        Button {
                            hapticImpact.impactOccurred()
                            withAnimation(.spring()) {
                                krakenPlayedInRound[currentRound] = !(krakenPlayedInRound[currentRound] ?? false)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text("🐙")
                                Text((krakenPlayedInRound[currentRound] ?? false) ? "Kraken actif (1 pli dévoré)" : "Kraken dans la manche ?")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle((krakenPlayedInRound[currentRound] ?? false) ? .white : .white.opacity(0.75))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill((krakenPlayedInRound[currentRound] ?? false) ? Color.purple : Color.white.opacity(0.10))
                            )
                        }
                    }
                    .padding(.top, 2)
                    
                    // Phase Toggle: Paris vs Plis/Résultats
                    HStack(spacing: 8) {
                        Button {
                            withAnimation { wizardPhase = .bets }
                        } label: {
                            Text("1. Paris (Annonces)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(wizardPhase == .bets ? .black : .white.opacity(0.7))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(wizardPhase == .bets ? Color.cyan : Color.white.opacity(0.08)))
                        }
                        
                        Button {
                            withAnimation { wizardPhase = .results }
                        } label: {
                            Text("2. Plis & Bonus")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(wizardPhase == .results ? .black : .white.opacity(0.7))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(wizardPhase == .results ? Color(red: 1.0, green: 0.35, blue: 0.45) : Color.white.opacity(0.08)))
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color(red: 0.10, green: 0.12, blue: 0.22))
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.1), lineWidth: 1))
                )
                .padding(.horizontal, 16)
                
                // Kraken Warning Banner
                if krakenPlayedInRound[currentRound] == true {
                    HStack(spacing: 8) {
                        Text("🐙")
                            .font(.system(size: 16))
                        Text("Kraken dévore le pli : il y a 1 pli de moins (seulement \(max(0, currentRound - 1)) pli(s) remportés au total).")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.purple.opacity(0.45))
                    )
                    .padding(.horizontal, 16)
                }
                
                // Active wizard instruction
                Text(wizardPhase == .bets ? "Touchez un pari pour chaque joueur (seules les valeurs possibles 0 à \(currentRound) sont proposées) :" : "Indiquez les plis réalisés et bonus obtenus :")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                
                // Players List for Current Round
                VStack(spacing: 12) {
                    ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                        let roundData = sheets[player.id]?.rounds[currentRound] ?? SkullKingRoundData()
                        playerWizardCard(player: player, index: index, data: roundData)
                    }
                }
                .padding(.horizontal, 16)
                
                // Navigation to next round
                if currentRound < totalRounds {
                    Button {
                        hapticSuccess.notificationOccurred(.success)
                        withAnimation(.spring()) {
                            currentRound += 1
                            wizardPhase = .bets
                        }
                    } label: {
                        HStack {
                            Text("Passer à la manche \(currentRound + 1)")
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.cyan))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                
                Spacer(minLength: 40)
            }
            .padding(.top, 12)
        }
    }
    
    // MARK: - Player Wizard Card
    private func playerWizardCard(player: Player, index: Int, data: SkullKingRoundData) -> some View {
        VStack(spacing: 10) {
            HStack {
                Circle()
                    .fill(player.color)
                    .frame(width: 26, height: 26)
                    .overlay(Text("\(index + 1)").font(.system(size: 11, weight: .black)).foregroundStyle(.white))
                
                Text(player.name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Spacer()
                
                // Score Preview for this round
                if let score = data.score(for: currentRound) {
                    HStack(spacing: 4) {
                        Text(score >= 0 ? "+\(score)" : "\(score)")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(score >= 0 ? .green : .red)
                        Text("pts")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                }
            }
            
            if wizardPhase == .bets {
                // BET PHASE
                // USER REQUIREMENT: "Pour les pari dans le skull king sur la premiere manche ne proposer que les touches 0 et 1"
                // For Round R: only buttons 0 to R!
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Pari annoncé :")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.65))
                        if let bet = data.bet {
                            Text("\(bet) \(bet == 0 ? "(Pari Zéro)" : "pli\(bet > 1 ? "s" : "")")")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(.cyan)
                        } else {
                            Text("En attente")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.orange.opacity(0.8))
                        }
                    }
                    
                    // Buttons 0 to currentRound (For round 1: strictly 0 and 1)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(0...currentRound, id: \.self) { betValue in
                                Button {
                                    hapticImpact.impactOccurred()
                                    var updated = data
                                    updated.bet = betValue
                                    sheets[player.id]?.rounds[currentRound] = updated
                                } label: {
                                    Text("\(betValue)")
                                        .font(.system(size: 17, weight: .black, design: .rounded))
                                        .foregroundStyle(data.bet == betValue ? .black : .white)
                                        .frame(width: 44, height: 44)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(data.bet == betValue ? Color.cyan : Color.white.opacity(0.12))
                                        )
                                }
                            }
                        }
                    }
                }
            } else {
                // RESULTS PHASE (Tricks & Bonus)
                VStack(spacing: 10) {
                    // Tricks Won: 0 to currentRound
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Plis réalisés :")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.65))
                            if let tricks = data.tricks {
                                Text("\(tricks) pli\(tricks > 1 ? "s" : "")")
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .foregroundStyle(data.bet == tricks ? .green : .red)
                            }
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(0...currentRound, id: \.self) { trickValue in
                                    Button {
                                        hapticImpact.impactOccurred()
                                        var updated = data
                                        updated.tricks = trickValue
                                        sheets[player.id]?.rounds[currentRound] = updated
                                    } label: {
                                        Text("\(trickValue)")
                                            .font(.system(size: 17, weight: .black, design: .rounded))
                                            .foregroundStyle(data.tricks == trickValue ? .black : .white)
                                            .frame(width: 44, height: 44)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(data.tricks == trickValue ? Color(red: 1.0, green: 0.35, blue: 0.45) : Color.white.opacity(0.12))
                                            )
                                    }
                                }
                            }
                        }
                    }
                    
                    // Bonus Stepper / Quick Chips with Butin (+20)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Bonus :")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.65))
                            
                            if data.bonus > 0 {
                                Text("+\(data.bonus) pts")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(.yellow)
                            }
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                // Butin (+20) button
                                Button {
                                    hapticImpact.impactOccurred()
                                    var updated = data
                                    updated.bonus += 20
                                    sheets[player.id]?.rounds[currentRound] = updated
                                } label: {
                                    HStack(spacing: 3) {
                                        Text("💰")
                                        Text("+20 Butin")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                    }
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Color.yellow))
                                }
                                
                                ForEach([0, 10, 20, 30, 40, 50], id: \.self) { bonusPreset in
                                    Button {
                                        hapticImpact.impactOccurred()
                                        var updated = data
                                        updated.bonus = bonusPreset
                                        sheets[player.id]?.rounds[currentRound] = updated
                                    } label: {
                                        Text(bonusPreset == 0 ? "0" : "+\(bonusPreset)")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .foregroundStyle(data.bonus == bonusPreset ? .black : .white.opacity(0.85))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(data.bonus == bonusPreset ? Color.white.opacity(0.85) : Color.white.opacity(0.1))
                                            )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }
    
    // MARK: - Full Table View (10 Rounds Matrix)
    private var fullTableView: some View {
        ScrollView([.vertical, .horizontal], showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                // Table Header
                HStack(spacing: 0) {
                    Text("MANCHE")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 10)
                        .frame(width: 90, height: 46)
                        .background(Color(red: 0.08, green: 0.10, blue: 0.18))
                    
                    ForEach(players) { player in
                        VStack(spacing: 2) {
                            Circle().fill(player.color).frame(width: 10, height: 10)
                            Text(player.name)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        .frame(width: 82, height: 46)
                        .background(Color(red: 0.08, green: 0.10, blue: 0.18))
                    }
                }
                
                Divider().background(Color.white.opacity(0.12))
                
                // Round Rows up to totalRounds
                ForEach(1...totalRounds, id: \.self) { round in
                    HStack(spacing: 0) {
                        // Sticky Round Label
                        VStack(alignment: .leading, spacing: 1) {
                            Text("M\(round)")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            Text("\(round) carte\(round > 1 ? "s" : "")")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(.horizontal, 10)
                        .frame(width: 90, height: 44, alignment: .leading)
                        .background(Color(red: 0.08, green: 0.10, blue: 0.18))
                        
                        // Player score for this round
                        ForEach(players) { player in
                            let roundData = sheets[player.id]?.rounds[round] ?? SkullKingRoundData()
                            let score = roundData.score(for: round)
                            
                            Button {
                                hapticImpact.impactOccurred()
                                selectedPlayerForDetail = SKDetailItem(player: player, round: round)
                            } label: {
                                VStack(spacing: 1) {
                                    if let score = score {
                                        Text(score >= 0 ? "+\(score)" : "\(score)")
                                            .font(.system(size: 13, weight: .black, design: .rounded))
                                            .foregroundStyle(score >= 0 ? .green : .red)
                                        
                                        // Bet / Trick tiny preview
                                        let bet = roundData.bet.map { "\($0)" } ?? "?"
                                        let tricks = roundData.tricks.map { "\($0)" } ?? "?"
                                        Text("\(bet)/\(tricks)")
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.45))
                                    } else {
                                        Text("—")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(.white.opacity(0.25))
                                    }
                                }
                                .frame(width: 82, height: 44)
                                .background(Color.white.opacity(0.02))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .overlay(Rectangle().frame(height: 0.5).foregroundStyle(Color.white.opacity(0.06)), alignment: .bottom)
                }
                
                Divider().background(Color.white.opacity(0.2))
                
                // Cumulative Total Row
                HStack(spacing: 0) {
                    Text("TOTAL")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(.cyan)
                        .padding(.horizontal, 10)
                        .frame(width: 90, height: 50, alignment: .leading)
                        .background(Color(red: 0.10, green: 0.12, blue: 0.22))
                    
                    ForEach(players) { player in
                        let sheet = sheets[player.id] ?? SkullKingPlayerSheet()
                        Text("\(sheet.totalScore(upTo: totalRounds))")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(.cyan)
                            .frame(width: 82, height: 50)
                            .background(Color.cyan.opacity(0.08))
                    }
                }
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Helpers
    private func initializeSheetsIfNeeded() {
        for player in players {
            if sheets[player.id] == nil {
                sheets[player.id] = SkullKingPlayerSheet()
            }
        }
    }
    
    private func resetGame() {
        for player in players {
            sheets[player.id] = SkullKingPlayerSheet()
        }
        currentRound = 1
        wizardPhase = .bets
    }
}

// MARK: - Helper Item for Modal
struct SKDetailItem: Identifiable {
    let id = UUID()
    let player: Player
    let round: Int
}

// MARK: - Skull King Detail Modal (Manual Edit for a Round)
struct SkullKingDetailModal: View {
    let player: Player
    let round: Int
    @State var data: SkullKingRoundData
    var onSave: (SkullKingRoundData) -> Void
    @Environment(\.dismiss) private var dismiss
    
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.10, blue: 0.18).ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    Circle().fill(player.color).frame(width: 28, height: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.name)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                        Text("Manche \(round) (\(round) cartes)")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Button("Fermer") { dismiss() }.foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Pari Buttons: 0 to round (Round 1 only 0 and 1)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pari annoncé (0 à \(round)) :")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(0...round, id: \.self) { val in
                                Button {
                                    haptic.impactOccurred()
                                    data.bet = val
                                } label: {
                                    Text("\(val)")
                                        .font(.system(size: 17, weight: .black, design: .rounded))
                                        .foregroundStyle(data.bet == val ? .black : .white)
                                        .frame(width: 44, height: 44)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(data.bet == val ? Color.cyan : Color.white.opacity(0.12)))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                // Tricks Buttons: 0 to round
                VStack(alignment: .leading, spacing: 8) {
                    Text("Plis réalisés (0 à \(round)) :")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(0...round, id: \.self) { val in
                                Button {
                                    haptic.impactOccurred()
                                    data.tricks = val
                                } label: {
                                    Text("\(val)")
                                        .font(.system(size: 17, weight: .black, design: .rounded))
                                        .foregroundStyle(data.tricks == val ? .black : .white)
                                        .frame(width: 44, height: 44)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(data.tricks == val ? Color(red: 1.0, green: 0.35, blue: 0.45) : Color.white.opacity(0.12)))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                // Bonus Buttons
                VStack(alignment: .leading, spacing: 8) {
                    Text("Points Bonus :")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button {
                                haptic.impactOccurred()
                                data.bonus += 20
                            } label: {
                                HStack(spacing: 3) {
                                    Text("💰")
                                    Text("+20 Butin")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                }
                                .foregroundStyle(.black)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.yellow))
                            }
                            
                            ForEach([0, 10, 20, 30, 40, 50], id: \.self) { b in
                                Button {
                                    haptic.impactOccurred()
                                    data.bonus = b
                                } label: {
                                    Text("+\(b)")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(data.bonus == b ? .black : .white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Capsule().fill(data.bonus == b ? Color.yellow : Color.white.opacity(0.12)))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                // Preview Score
                if let score = data.score(for: round) {
                    Text("Score de la manche : \(score >= 0 ? "+\(score)" : "\(score)") pts")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(score >= 0 ? .green : .red)
                }
                
                Button {
                    onSave(data)
                    dismiss()
                } label: {
                    Text("Enregistrer")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.cyan))
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
    }
}

// MARK: - Skull King Leaderboard
struct SkullKingLeaderboardSheet: View {
    let players: [Player]
    let sheets: [UUID: SkullKingPlayerSheet]
    @Environment(\.dismiss) private var dismiss
    
    var sortedPlayers: [(player: Player, score: Int)] {
        players.map { ($0, sheets[$0.id]?.totalScore ?? 0) }
            .sorted { $0.score > $1.score }
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
                                
                                Circle()
                                    .fill(item.player.color)
                                    .frame(width: 28, height: 28)
                                
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
            .navigationTitle("Classement Skull King")
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
