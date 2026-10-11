import SwiftUI
import UIKit

struct YamsView: View {
    @Binding var currentScreen: AppScreen
    @Binding var players: [Player]
    
    @State private var sheets: [UUID: YamsPlayerSheet] = [:]
    @State private var activePlayerIndex: Int = 0
    @State private var selectedCell: SelectedCellItem? = nil
    @State private var showingResetAlert: Bool = false
    @State private var showingRankingSheet: Bool = false
    
    private let hapticImpact = UIImpactFeedbackGenerator(style: .medium)
    private let hapticSuccess = UINotificationFeedbackGenerator()
    
    // Column widths
    private let labelColWidth: CGFloat = 118
    private let playerColWidth: CGFloat = 78
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.06, blue: 0.11).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Turn / Active Player Banner
                    activePlayerBanner
                    
                    // Main Score Table
                    ScrollViewReader { proxy in
                        ScrollView([.vertical, .horizontal], showsIndicators: true) {
                            VStack(alignment: .leading, spacing: 0) {
                                // Header Row: Players
                                tableHeaderRow(proxy: proxy)
                                
                                Divider().background(Color.white.opacity(0.15))
                                
                                // Section Supérieure
                                sectionTitleRow("SECTION SUPÉRIEURE")
                                ForEach([YamsCategory.ones, .twos, .threes, .fours, .fives, .sixes], id: \.self) { cat in
                                    categoryRow(category: cat)
                                }
                                
                                // Sous-Total Supérieur & Bonus
                                summaryRow(title: "Sous-Total Sup.", subtitle: "Objectif 63 pts") { sheet in
                                    "\(sheet.upperTotal)"
                                }
                                
                                bonusRow
                                
                                summaryRow(title: "Total Supérieur", subtitle: "Avec prime") { sheet in
                                    "\(sheet.totalUpperWithBonus)"
                                }
                                .background(Color.white.opacity(0.04))
                                
                                Divider().background(Color.white.opacity(0.15))
                                
                                // Section Inférieure
                                sectionTitleRow("SECTION INFÉRIEURE")
                                ForEach([
                                    YamsCategory.threeOfAKind, .fourOfAKind, .fullHouse,
                                    .smallStraight, .largeStraight, .yahtzee, .chance
                                ], id: \.self) { cat in
                                    categoryRow(category: cat)
                                }
                                
                                summaryRow(title: "Total Inférieur", subtitle: "") { sheet in
                                    "\(sheet.lowerTotal)"
                                }
                                .background(Color.white.opacity(0.04))
                                
                                Divider().background(Color.white.opacity(0.2))
                                
                                // Grand Total Row
                                grandTotalRow
                            }
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
            .navigationTitle("Feuille de Yams")
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
                            showingRankingSheet = true
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
            .alert("Nouvelle partie de Yams ?", isPresented: $showingResetAlert) {
                Button("Annuler", role: .cancel) {}
                Button("Recommencer", role: .destructive) {
                    resetGame()
                }
            } message: {
                Text("Tous les scores actuels seront réinitialisés.")
            }
            .sheet(item: $selectedCell) { item in
                YamsScoreInputSheet(
                    player: item.player,
                    category: item.category,
                    currentScore: sheets[item.player.id]?.scores[item.category],
                    onScoreSelected: { score in
                        applyScoreAndAdvance(player: item.player, category: item.category, score: score)
                    }
                )
                .presentationDetents([.medium, .fraction(0.68)])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingRankingSheet) {
                YamsLeaderboardSheet(players: players, sheets: sheets)
            }
            .onAppear {
                initializeSheetsIfNeeded()
            }
        }
    }
    
    // MARK: - Active Player Banner
    private var activePlayerBanner: some View {
        let activePlayer = players.indices.contains(activePlayerIndex) ? players[activePlayerIndex] : players.first
        return HStack(spacing: 12) {
            if let activePlayer = activePlayer {
                Circle()
                    .fill(activePlayer.color)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text("\(activePlayerIndex + 1)")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(.white)
                    )
                
                Text("Tour de :")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                
                Text(activePlayer.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Spacer()
                
                // Button to manually skip to next player if desired
                Button {
                    advanceToNextPlayer()
                } label: {
                    HStack(spacing: 4) {
                        Text("Suivant")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.cyan.opacity(0.15)))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(red: 0.10, green: 0.12, blue: 0.20))
    }
    
    // MARK: - Table Header Row
    private func tableHeaderRow(proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 0) {
            // Top-Left corner cell (Sticky label)
            HStack {
                Text("CATÉGORIE")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(width: labelColWidth, height: 50)
            .background(Color(red: 0.07, green: 0.08, blue: 0.14))
            
            // Player Columns
            ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                let isActive = index == activePlayerIndex
                let rank = getRank(for: player)
                
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(player.color)
                            .frame(width: 10, height: 10)
                        
                        Text(player.name)
                            .font(.system(size: 13, weight: isActive ? .black : .bold, design: .rounded))
                            .foregroundStyle(isActive ? .cyan : .white)
                            .lineLimit(1)
                    }
                    
                    if let rank = rank {
                        Text(rank)
                            .font(.system(size: 10, weight: .bold))
                    }
                }
                .frame(width: playerColWidth, height: 50)
                .background(isActive ? Color.cyan.opacity(0.12) : Color.clear)
                .id(player.id)
                .onTapGesture {
                    withAnimation {
                        activePlayerIndex = index
                    }
                }
            }
            
            // Add Player Button Column
            Button {
                addNewPlayer()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.cyan.opacity(0.8))
                    .frame(width: 44, height: 50)
            }
        }
        .background(Color(red: 0.07, green: 0.08, blue: 0.14))
    }
    
    // MARK: - Section Title Row
    private func sectionTitleRow(_ title: String) -> some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.cyan.opacity(0.85))
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 28)
        .background(Color.cyan.opacity(0.08))
    }
    
    // MARK: - Category Row
    private func categoryRow(category: YamsCategory) -> some View {
        HStack(spacing: 0) {
            // Category Name Label
            VStack(alignment: .leading, spacing: 2) {
                Text(category.rawValue)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(width: labelColWidth, height: 42, alignment: .leading)
            .background(Color(red: 0.07, green: 0.08, blue: 0.14))
            
            // Player score cells
            ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                let isActive = index == activePlayerIndex
                let score = sheets[player.id]?.scores[category]
                
                Button {
                    hapticImpact.impactOccurred()
                    selectedCell = SelectedCellItem(player: player, category: category)
                } label: {
                    ZStack {
                        if isActive {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.cyan.opacity(0.35), lineWidth: 1)
                                .padding(2)
                        }
                        
                        if let score = score {
                            if score == 0 {
                                // Crossed out / zero
                                Text("—")
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                    .foregroundStyle(.red.opacity(0.7))
                            } else {
                                Text("\(score)")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                        } else {
                            // Empty cell
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .frame(width: playerColWidth, height: 42)
                    .background(isActive ? Color.cyan.opacity(0.06) : Color.white.opacity(0.02))
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(Color.white.opacity(0.06)),
            alignment: .bottom
        )
    }
    
    // MARK: - Bonus Row
    private var bonusRow: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Prime (+35 pts)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.yellow)
                Text("si ≥ 63")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.horizontal, 10)
            .frame(width: labelColWidth, height: 42, alignment: .leading)
            .background(Color(red: 0.07, green: 0.08, blue: 0.14))
            
            ForEach(players) { player in
                let sheet = sheets[player.id] ?? YamsPlayerSheet()
                let bonus = sheet.upperBonus
                let delta = sheet.upperDelta
                
                VStack(spacing: 1) {
                    Text(bonus > 0 ? "+35" : "0")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(bonus > 0 ? .yellow : .white.opacity(0.35))
                    
                    // Show progress delta towards 63 pts
                    if sheet.upperTotal < 63 {
                        Text("\(delta)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.orange.opacity(0.75))
                    }
                }
                .frame(width: playerColWidth, height: 42)
                .background(Color.yellow.opacity(bonus > 0 ? 0.08 : 0.02))
            }
            Spacer()
        }
        .overlay(
            Rectangle().frame(height: 0.5).foregroundStyle(Color.white.opacity(0.06)),
            alignment: .bottom
        )
    }
    
    // MARK: - Summary Row Helper
    private func summaryRow(title: String, subtitle: String, valueFor: @escaping (YamsPlayerSheet) -> String) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 10)
            .frame(width: labelColWidth, height: 40, alignment: .leading)
            .background(Color(red: 0.07, green: 0.08, blue: 0.14))
            
            ForEach(players) { player in
                let sheet = sheets[player.id] ?? YamsPlayerSheet()
                Text(valueFor(sheet))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: playerColWidth, height: 40)
            }
            Spacer()
        }
        .overlay(
            Rectangle().frame(height: 0.5).foregroundStyle(Color.white.opacity(0.06)),
            alignment: .bottom
        )
    }
    
    // MARK: - Grand Total Row
    private var grandTotalRow: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("TOTAL GÉNÉRAL")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.cyan)
            }
            .padding(.horizontal, 10)
            .frame(width: labelColWidth, height: 50, alignment: .leading)
            .background(Color(red: 0.09, green: 0.11, blue: 0.18))
            
            ForEach(players) { player in
                let sheet = sheets[player.id] ?? YamsPlayerSheet()
                VStack(spacing: 1) {
                    Text("\(sheet.grandTotal)")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.cyan)
                    
                    Text("\(sheet.completedCount)/13")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .frame(width: playerColWidth, height: 50)
                .background(Color.cyan.opacity(0.08))
            }
            Spacer()
        }
    }
    
    // MARK: - Auto-Advance Logic
    /// Requirement: "si on coche une case au yams ca nous passe dans la colonne du joueur suivant"
    private func applyScoreAndAdvance(player: Player, category: YamsCategory, score: Int) {
        if sheets[player.id] == nil {
            sheets[player.id] = YamsPlayerSheet()
        }
        sheets[player.id]?.scores[category] = score
        
        hapticSuccess.notificationOccurred(.success)
        
        // Find player's current index and advance to next
        if let currentIdx = players.firstIndex(where: { $0.id == player.id }) {
            let nextIndex = (currentIdx + 1) % players.count
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                activePlayerIndex = nextIndex
            }
        }
        
        // Dismiss sheet
        selectedCell = nil
    }
    
    private func advanceToNextPlayer() {
        hapticImpact.impactOccurred()
        withAnimation(.spring()) {
            activePlayerIndex = (activePlayerIndex + 1) % players.count
        }
    }
    
    private func addNewPlayer() {
        let newIdx = players.count + 1
        let newPlayer = Player(name: "Joueur \(newIdx)", colorHex: AppPalette.hex(at: players.count))
        players.append(newPlayer)
        sheets[newPlayer.id] = YamsPlayerSheet()
    }
    
    private func initializeSheetsIfNeeded() {
        for player in players {
            if sheets[player.id] == nil {
                sheets[player.id] = YamsPlayerSheet()
            }
        }
    }
    
    private func resetGame() {
        for player in players {
            sheets[player.id] = YamsPlayerSheet()
        }
        activePlayerIndex = 0
    }
    
    private func getRank(for player: Player) -> String? {
        let sorted = players.sorted {
            (sheets[$0.id]?.grandTotal ?? 0) > (sheets[$1.id]?.grandTotal ?? 0)
        }
        guard let idx = sorted.firstIndex(where: { $0.id == player.id }),
              (sheets[player.id]?.completedCount ?? 0) > 0 else { return nil }
        
        switch idx {
        case 0: return "🥇 1er"
        case 1: return "🥈 2e"
        case 2: return "🥉 3e"
        default: return "\(idx + 1)e"
        }
    }
}

// MARK: - Selected Cell Item for Sheet
struct SelectedCellItem: Identifiable {
    let id = UUID()
    let player: Player
    let category: YamsCategory
}

// MARK: - Fast Numeric Score Input Sheet
struct YamsScoreInputSheet: View {
    let player: Player
    let category: YamsCategory
    let currentScore: Int?
    var onScoreSelected: (Int) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var manualScoreText: String = ""
    @State private var showingCustomKeypad: Bool = false
    
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.10, blue: 0.16).ignoresSafeArea()
            
            VStack(spacing: 18) {
                // Header
                HStack(spacing: 12) {
                    Circle()
                        .fill(player.color)
                        .frame(width: 32, height: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.name)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                        
                        Text(category.rawValue)
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Text(category.subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                
                // Quick Choices based on Category
                if showingCustomKeypad {
                    NumericKeypadView(
                        textValue: $manualScoreText,
                        title: "Score libre",
                        allowNegative: false,
                        quickPresets: [15, 18, 20, 22, 24, 26, 28, 30],
                        onValidate: { val in
                            onScoreSelected(val)
                            dismiss()
                        },
                        onCancel: {
                            showingCustomKeypad = false
                        }
                    )
                    .padding(.horizontal, 16)
                } else {
                    categoryQuickOptions
                }
                
                Spacer()
            }
        }
        .onAppear {
            if let currentScore = currentScore {
                manualScoreText = "\(currentScore)"
            }
        }
    }
    
    @ViewBuilder
    private var categoryQuickOptions: some View {
        VStack(spacing: 14) {
            // "0 (Barré)" Option - Always available for any category
            Button {
                haptic.impactOccurred()
                onScoreSelected(0)
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("Barrer la case (0 point)")
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.red.opacity(0.9))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.red.opacity(0.12)))
            }
            .padding(.horizontal, 20)
            
            // Fixed Categories: Full (25), Petite Suite (30), Grande Suite (40), Yams (50)
            if let fixed = category.fixedValue {
                Button {
                    haptic.impactOccurred()
                    onScoreSelected(fixed)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Valider \(fixed) points")
                    }
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.cyan))
                }
                .padding(.horizontal, 20)
            }
            // Upper section (1 to 6): Multipliers 1x to 5x
            else if let dice = category.diceValue {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nombre de dés réalisés (\(dice)) :")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 20)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        ForEach(1...5, id: \.self) { count in
                            let points = count * dice
                            Button {
                                haptic.impactOccurred()
                                onScoreSelected(points)
                                dismiss()
                            } label: {
                                VStack(spacing: 3) {
                                    Text("\(count) dés")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.65))
                                    Text("\(points) pts")
                                        .font(.system(size: 18, weight: .black, design: .rounded))
                                        .foregroundStyle(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.white.opacity(0.10))
                                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cyan.opacity(0.4), lineWidth: 1))
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            // Variable categories (Brelan, Carré, Chance)
            else {
                VStack(spacing: 10) {
                    Text("Sélectionnez la somme totale des 5 dés :")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                    
                    // Quick common sums
                    let commonSums = [15, 18, 20, 22, 24, 25, 26, 28, 30]
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(commonSums, id: \.self) { sum in
                            Button {
                                haptic.impactOccurred()
                                onScoreSelected(sum)
                                dismiss()
                            } label: {
                                Text("\(sum) pts")
                                    .font(.system(size: 17, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.10))
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Button {
                        showingCustomKeypad = true
                    } label: {
                        HStack {
                            Image(systemName: "keyboard")
                            Text("Saisie manuelle précise (Pavé numérique)")
                        }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.cyan)
                        .padding(.top, 4)
                    }
                }
            }
        }
    }
}

// MARK: - Yams Leaderboard Sheet
struct YamsLeaderboardSheet: View {
    let players: [Player]
    let sheets: [UUID: YamsPlayerSheet]
    @Environment(\.dismiss) private var dismiss
    
    var sortedPlayers: [(player: Player, sheet: YamsPlayerSheet)] {
        players.map { ($0, sheets[$0.id] ?? YamsPlayerSheet()) }
            .sorted { $0.sheet.grandTotal > $1.sheet.grandTotal }
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
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.player.name)
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                    
                                    Text("Supérieur: \(item.sheet.totalUpperWithBonus) • Inférieur: \(item.sheet.lowerTotal)")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.55))
                                }
                                
                                Spacer()
                                
                                Text("\(item.sheet.grandTotal) pts")
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
            .navigationTitle("Classement Yams")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                        .foregroundStyle(.cyan)
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
