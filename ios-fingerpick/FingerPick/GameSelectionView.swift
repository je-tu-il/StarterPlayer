import SwiftUI

struct GameSelectionView: View {
    @Binding var currentScreen: AppScreen
    @Binding var players: [Player]
    
    @State private var showingPlayerEditor: Bool = false
    @State private var editingPlayer: Player? = nil
    @State private var newPlayerName: String = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                AtmosphericBackground()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 6) {
                            Text("Sélection du Jeu")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            
                            Text("Choisissez une feuille de score intelligente")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        .padding(.top, 16)
                        
                        // Player Roster Bar
                        playerRosterCard
                        
                        // Game Cards
                        VStack(spacing: 18) {
                            // 1. YAMS CARD
                            gameCard(
                                title: "Yams",
                                subtitle: "Yahtzee classique avec feuille de score intelligente",
                                icon: "die.face.5.fill",
                                gradient: [Color.purple, Color.indigo],
                                tags: ["Passage auto au joueur suivant", "Bonus 63 pts", "Pavé tactile"],
                                targetScreen: .yams
                            )
                            
                            // 2. SKULL KING CARD
                            gameCard(
                                title: "Skull King",
                                subtitle: "10 manches avec contrainte stricte sur les paris",
                                icon: "shield.checkered",
                                gradient: [Color(red: 0.85, green: 0.2, blue: 0.35), Color(red: 0.5, green: 0.1, blue: 0.3)],
                                tags: ["Manche 1 : touches 0 et 1", "Pari Zéro auto", "Bonus pirates"],
                                targetScreen: .skullKing
                            )
                            
                            // 3. FEUILLE BASIQUE CARD
                            gameCard(
                                title: "Feuille Basique",
                                subtitle: "Score universel pour Uno, Skyjo, Tarot, 6 qui prend...",
                                icon: "list.bullet.clipboard.fill",
                                gradient: [Color(red: 0.05, green: 0.65, blue: 0.8), Color(red: 0.02, green: 0.4, blue: 0.6)],
                                tags: ["Joueurs illimités", "Manche par manche", "Podium en direct"],
                                targetScreen: .basicScoreSheet
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.bottom, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.spring()) {
                            currentScreen = .voicePick
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Tirage")
                        }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.cyan)
                    }
                }
            }
        }
        .sheet(item: $editingPlayer) { player in
            PlayerEditSheet(
                player: player,
                onSave: { updated in
                    if let idx = players.firstIndex(where: { $0.id == updated.id }) {
                        players[idx] = updated
                    }
                },
                onDelete: {
                    players.removeAll(where: { $0.id == player.id })
                }
            )
        }
    }
    
    // MARK: - Player Roster Card
    private var playerRosterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(.cyan)
                    Text("Joueurs inscrits (\(players.count))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                Button {
                    addNewPlayer()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Ajouter")
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.cyan.opacity(0.18)))
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                        Button {
                            editingPlayer = player
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(player.color)
                                    .frame(width: 22, height: 22)
                                    .overlay(
                                        Text("\(index + 1)")
                                            .font(.system(size: 11, weight: .black))
                                            .foregroundStyle(.white)
                                    )
                                
                                Text(player.name)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                
                                Image(systemName: "pencil")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(Capsule().stroke(player.color.opacity(0.5), lineWidth: 1))
                            )
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Game Card Builder
    private func gameCard(
        title: String,
        subtitle: String,
        icon: String,
        gradient: [Color],
        tags: [String],
        targetScreen: AppScreen
    ) -> some View {
        Button {
            ensureMinimumPlayers()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                currentScreen = targetScreen
            }
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 54, height: 54)
                            .shadow(color: gradient.first?.opacity(0.5) ?? .clear, radius: 10)
                        
                        Image(systemName: icon)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Text(subtitle)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.leading, 6)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(gradient.first ?? .cyan)
                }
                
                // Tags
                FlowLayoutView(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.12))
                            )
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 0.08, green: 0.10, blue: 0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    colors: [gradient.first?.opacity(0.6) ?? .white.opacity(0.2), Color.white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: .black.opacity(0.4), radius: 14, y: 6)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helpers
    private func addNewPlayer() {
        let newIdx = players.count + 1
        let player = Player(
            name: "Joueur \(newIdx)",
            colorHex: AppPalette.hex(at: players.count)
        )
        withAnimation(.spring()) {
            players.append(player)
        }
    }
    
    private func ensureMinimumPlayers() {
        if players.isEmpty {
            players = (1...4).map { idx in
                Player(name: "Joueur \(idx)", colorHex: AppPalette.hex(at: idx - 1))
            }
        }
    }
}

// MARK: - Flow Layout for Tags
struct FlowLayoutView: Layout {
    var spacing: CGFloat = 6
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeightInRow: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                y += maxHeightInRow + spacing
                maxHeightInRow = 0
            }
            maxHeightInRow = max(maxHeightInRow, size.height)
            x += size.width + spacing
        }
        height = y + maxHeightInRow
        return CGSize(width: width, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var maxHeightInRow: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += maxHeightInRow + spacing
                maxHeightInRow = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            maxHeightInRow = max(maxHeightInRow, size.height)
            x += size.width + spacing
        }
    }
}

// MARK: - Player Edit Sheet
struct PlayerEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var player: Player
    var onSave: (Player) -> Void
    var onDelete: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.08, green: 0.10, blue: 0.16).ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nom du joueur")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                        
                        TextField("Nom", text: $player.name)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.08)))
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Couleur")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 12) {
                            ForEach(AppPalette.colors, id: \.hex) { item in
                                Circle()
                                    .fill(Color(hex: item.hex))
                                    .frame(width: 38, height: 38)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(Color.white, lineWidth: player.colorHex == item.hex ? 3.5 : 0)
                                    )
                                    .onTapGesture {
                                        player.colorHex = item.hex
                                    }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Supprimer ce joueur")
                        }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.red)
                    }
                    .padding(.bottom, 12)
                }
                .padding(24)
            }
            .navigationTitle("Modifier le joueur")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        onSave(player)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(.cyan)
                }
            }
        }
    }
}
