import SwiftUI
import UIKit
import Speech
import AVFoundation

struct VoiceFirstPlayerView: View {
    @Binding var currentScreen: AppScreen
    @Binding var gamePlayers: [Player]
    
    @StateObject private var speechManager = SpeechRecognizerManager()
    @State private var playersList: [Player] = []
    
    // UI & Draw States
    @State private var drawState: DrawState = .registering
    @State private var winnerPlayer: Player? = nil
    @State private var activeRollIndex: Int = 0
    @State private var manualNameText: String = ""
    @State private var showingManualInput: Bool = false
    @State private var permissionAlert: Bool = false
    
    // Table order reordering state
    @State private var tableOrderRemaining: [Player] = []
    
    private let hapticImpact = UIImpactFeedbackGenerator(style: .medium)
    private let hapticTick = UIImpactFeedbackGenerator(style: .light)
    private let hapticSuccess = UINotificationFeedbackGenerator()
    
    enum DrawState {
        case registering
        case rolling
        case winnerAnnounced
        case tableOrdering
    }
    
    var body: some View {
        ZStack {
            AtmosphericBackground()
            
            VStack(spacing: 0) {
                // Top Header Bar
                topHeaderBar
                
                // Main Content depending on drawState
                switch drawState {
                case .registering:
                    registeringView
                case .rolling:
                    rollingAnimationView
                case .winnerAnnounced:
                    winnerRevealView
                case .tableOrdering:
                    tableOrderingView
                }
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .alert("Microphone & Voix requis", isPresented: $permissionAlert) {
            Button("Ouvrir les Réglages") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Continuer en saisie manuelle", role: .cancel) {
                showingManualInput = true
            }
        } message: {
            Text("Activez la reconnaissance vocale pour que chacun puisse dire son prénom au micro.")
        }
        .onAppear {
            if !gamePlayers.isEmpty && playersList.isEmpty {
                playersList = gamePlayers
            }
        }
        .onDisappear {
            speechManager.stopListening()
        }
    }
    
    // MARK: - Top Header Bar
    private var topHeaderBar: some View {
        HStack {
            // Mode Switcher (Option to use Finger Pick if preferred)
            Button {
                speechManager.stopListening()
                withAnimation(.spring()) {
                    currentScreen = .fingerPick
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "hand.tap.fill")
                    Text("Mode Doigts")
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.white.opacity(0.1)))
            }
            
            Spacer()
            
            // Title Pill
            HStack(spacing: 6) {
                Image(systemName: "mic.fill")
                    .foregroundStyle(.cyan)
                Text("Tirage Vocal")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.white.opacity(0.08)))
            
            Spacer()
            
            // Reset / Clear button
            Button {
                resetAll()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 50)
        .padding(.bottom, 10)
    }
    
    // MARK: - 1. Registering View (Mic in center + Bubbles)
    private var registeringView: some View {
        VStack(spacing: 16) {
            // Instruction
            VStack(spacing: 4) {
                Text("Chacun dit son prénom")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                
                Text(speechManager.isListening ? "🎙️ Parlez au micro... Vos bulles vont apparaître !" : "Touchez le micro au centre pour commencer")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(speechManager.isListening ? .cyan : .white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 10)
            .padding(.horizontal, 24)
            
            // Interactive Center Hub (Bubbles + Microphone)
            ZStack {
                // Center Microphone Button
                centralMicrophoneButton
                
                // Bubbles around the microphone
                bubblesOrbitView
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Manual Add & Start Button Controls
            VStack(spacing: 12) {
                // Manual input bar toggle (in case of loud party)
                if showingManualInput {
                    HStack(spacing: 8) {
                        TextField("Entrer un prénom...", text: $manualNameText)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.12)))
                        
                        Button {
                            addManualName()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.cyan)
                        }
                        .disabled(manualNameText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Button {
                        withAnimation { showingManualInput = true }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "keyboard")
                            Text("Ajouter au clavier si besoin")
                        }
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                    }
                }
                
                // BIG START BUTTON (Appears when >= 2 players)
                if playersList.count >= 2 {
                    Button {
                        startClassyDraw()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 20, weight: .black))
                            Text("START : QUI COMMENCE ?")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [Color.cyan, Color(red: 0.1, green: 0.9, blue: 0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: .cyan.opacity(0.5), radius: 18, y: 6)
                    }
                    .padding(.horizontal, 24)
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Text("Au moins 2 joueurs requis pour lancer le tirage")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Central Microphone Button
    private var centralMicrophoneButton: some View {
        Button {
            handleMicTap()
        } label: {
            ZStack {
                // Pulsing Audio Wave Rings when listening
                if speechManager.isListening {
                    Circle()
                        .stroke(Color.cyan.opacity(0.25), lineWidth: 4)
                        .frame(width: 140 + CGFloat(speechManager.audioLevel * 70),
                               height: 140 + CGFloat(speechManager.audioLevel * 70))
                        .animation(.easeInOut(duration: 0.15), value: speechManager.audioLevel)
                    
                    Circle()
                        .stroke(Color.cyan.opacity(0.5), lineWidth: 2)
                        .frame(width: 115 + CGFloat(speechManager.audioLevel * 45),
                               height: 115 + CGFloat(speechManager.audioLevel * 45))
                        .animation(.easeInOut(duration: 0.15), value: speechManager.audioLevel)
                }
                
                // Mic Button Core
                Circle()
                    .fill(
                        LinearGradient(
                            colors: speechManager.isListening
                                ? [Color.cyan, Color(red: 0.2, green: 0.6, blue: 1.0)]
                                : [Color.white.opacity(0.18), Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                    .overlay(
                        Circle().strokeBorder(speechManager.isListening ? Color.white : Color.white.opacity(0.25), lineWidth: 2)
                    )
                    .shadow(color: speechManager.isListening ? Color.cyan.opacity(0.6) : .black.opacity(0.3), radius: 20)
                
                Image(systemName: speechManager.isListening ? "mic.fill" : "mic")
                    .font(.system(size: 36, weight: .black))
                    .foregroundStyle(speechManager.isListening ? .black : .white)
            }
        }
    }
    
    // MARK: - Bubbles Orbit View
    private var bubblesOrbitView: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let count = playersList.count
            let radius = min(geometry.size.width, geometry.size.height) * 0.38
            
            ForEach(Array(playersList.enumerated()), id: \.element.id) { index, player in
                let angle = (Double(index) / Double(max(1, count))) * 2.0 * .pi - (.pi / 2.0)
                let x = center.x + CGFloat(cos(angle)) * radius
                let y = center.y + CGFloat(sin(angle)) * radius
                
                PlayerBubbleView(
                    player: player,
                    onDelete: {
                        removePlayer(player)
                    }
                )
                .position(x: x, y: y)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    // MARK: - 2. Rolling Animation View (Classy Spotlight Roulette)
    private var rollingAnimationView: some View {
        VStack(spacing: 24) {
            Text("TIRAGE DU PREMIER JOUEUR...")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.cyan)
                .padding(.top, 20)
            
            ZStack {
                GeometryReader { geometry in
                    let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    let count = playersList.count
                    let radius = min(geometry.size.width, geometry.size.height) * 0.36
                    
                    // Center Spinner Icon
                    Circle()
                        .stroke(Color.cyan.opacity(0.2), lineWidth: 4)
                        .frame(width: 90, height: 90)
                        .position(center)
                    
                    Image(systemName: "crown.fill")
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(.yellow)
                        .position(center)
                    
                    ForEach(Array(playersList.enumerated()), id: \.element.id) { index, player in
                        let angle = (Double(index) / Double(max(1, count))) * 2.0 * .pi - (.pi / 2.0)
                        let x = center.x + CGFloat(cos(angle)) * radius
                        let y = center.y + CGFloat(sin(angle)) * radius
                        let isHighlighted = index == activeRollIndex
                        
                        ZStack {
                            Circle()
                                .fill(player.color)
                                .frame(width: isHighlighted ? 84 : 64, height: isHighlighted ? 84 : 64)
                                .overlay(
                                    Circle().strokeBorder(Color.white, lineWidth: isHighlighted ? 4 : 1.5)
                                )
                                .shadow(color: player.color.opacity(isHighlighted ? 0.9 : 0.3), radius: isHighlighted ? 24 : 8)
                            
                            Text(player.name)
                                .font(.system(size: isHighlighted ? 16 : 13, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .padding(.horizontal, 6)
                        }
                        .scaleEffect(isHighlighted ? 1.25 : 0.9)
                        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isHighlighted)
                        .position(x: x, y: y)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Text("Suspense...")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.bottom, 36)
        }
    }
    
    // MARK: - 3. Winner Reveal View
    private var winnerRevealView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            if let winner = winnerPlayer {
                VStack(spacing: 16) {
                    // Big Crown Animation
                    Image(systemName: "crown.fill")
                        .font(.system(size: 56, weight: .black))
                        .foregroundStyle(
                            LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: .yellow.opacity(0.6), radius: 20)
                        .scaleEffect(1.1)
                    
                    // Winner Bubble
                    ZStack {
                        Circle()
                            .fill(winner.color)
                            .frame(width: 140, height: 140)
                            .overlay(Circle().strokeBorder(Color.white, lineWidth: 5))
                            .shadow(color: winner.color.opacity(0.8), radius: 30)
                        
                        Text(winner.name)
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .padding(.horizontal, 10)
                    }
                    
                    VStack(spacing: 6) {
                        Text("\(winner.name) commence !")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Text("1er joueur sélectionné au sort")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.cyan)
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            Spacer()
            
            // Action to proceed to Table Ordering
            Button {
                proceedToTableOrdering()
            } label: {
                HStack(spacing: 8) {
                    Text("Organiser le tour de table")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    LinearGradient(colors: [Color.cyan, Color(red: 0.2, green: 0.9, blue: 0.6)], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(Capsule())
                .shadow(color: .cyan.opacity(0.4), radius: 14, y: 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
    }
    
    // MARK: - 4. Table Ordering View (Reorder remaining players)
    // Requirement: "possible de remanier les places apres le premier joueur puis valider (pour permettre de respecter un tour de table. Ensuite les prenoms sont deja pret pour la partie"
    private var tableOrderingView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Tour de Table")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                
                Text("Ajustez l'ordre ci-dessous pour suivre les places physiques autour de votre table.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 10)
            
            // Fixed First Player Card (Winner)
            if let winner = winnerPlayer {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(winner.color).frame(width: 44, height: 44)
                        Image(systemName: "crown.fill").foregroundStyle(.yellow).font(.system(size: 20))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("1er JOUEUR (COMMENCE)")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(.yellow)
                        Text(winner.name)
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    
                    Spacer()
                    
                    Text("Place fixe")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(red: 0.12, green: 0.15, blue: 0.24))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.yellow.opacity(0.7), lineWidth: 1.5))
                )
                .padding(.horizontal, 20)
            }
            
            // Subtitle & Invert Button
            HStack {
                Text("JOUEURS SUIVANTS :")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                
                Spacer()
                
                Button {
                    hapticImpact.impactOccurred()
                    withAnimation(.spring()) {
                        tableOrderRemaining.reverse()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text("Inverser sens")
                    }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.cyan.opacity(0.12)))
                }
            }
            .padding(.horizontal, 24)
            
            // Reorderable list of remaining players
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Array(tableOrderRemaining.enumerated()), id: \.element.id) { index, player in
                        let seatNumber = index + 2
                        HStack(spacing: 12) {
                            Text("\(seatNumber)e")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundStyle(.cyan)
                                .frame(width: 32)
                            
                            Circle()
                                .fill(player.color)
                                .frame(width: 32, height: 32)
                            
                            Text(player.name)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            
                            Spacer()
                            
                            // Reorder Arrows
                            HStack(spacing: 8) {
                                Button {
                                    movePlayerUp(at: index)
                                } label: {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(index > 0 ? Color.white.opacity(0.7) : Color.white.opacity(0.15))
                                }
                                .disabled(index == 0)
                                
                                Button {
                                    movePlayerDown(at: index)
                                } label: {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(index < tableOrderRemaining.count - 1 ? Color.white.opacity(0.7) : Color.white.opacity(0.15))
                                }
                                .disabled(index == tableOrderRemaining.count - 1)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.06))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
            
            // Final Validation CTA: Ready for game!
            Button {
                finalizeTableOrderAndGoToGames()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                    Text("Valider le tour de table & Choisir un jeu")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    LinearGradient(colors: [Color.cyan, Color(red: 0.1, green: 0.9, blue: 0.7)], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(Capsule())
                .shadow(color: .cyan.opacity(0.4), radius: 14, y: 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Logic & Actions
    private func handleMicTap() {
        Task {
            if speechManager.authorizationStatus == .notDetermined {
                let granted = await speechManager.requestAuthorization()
                if !granted {
                    permissionAlert = true
                    return
                }
            } else if speechManager.authorizationStatus != .authorized {
                permissionAlert = true
                return
            }
            
            hapticImpact.impactOccurred()
            speechManager.toggleListening { detectedName in
                addPlayerWithName(detectedName)
            }
        }
    }
    
    private func addPlayerWithName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Avoid duplicate exact names
        guard !playersList.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) else { return }
        
        let colorHex = AppPalette.hex(at: playersList.count)
        let newPlayer = Player(name: trimmed, colorHex: colorHex)
        
        hapticSuccess.notificationOccurred(.success)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
            playersList.append(newPlayer)
        }
    }
    
    private func addManualName() {
        addPlayerWithName(manualNameText)
        manualNameText = ""
    }
    
    private func removePlayer(_ player: Player) {
        hapticImpact.impactOccurred()
        withAnimation(.spring()) {
            playersList.removeAll(where: { $0.id == player.id })
        }
    }
    
    private func startClassyDraw() {
        speechManager.stopListening()
        hapticImpact.impactOccurred()
        
        guard playersList.count >= 2 else { return }
        
        withAnimation {
            drawState = .rolling
        }
        
        // Pick a final winner randomly
        let winnerIndex = Int.random(in: 0..<playersList.count)
        let totalSteps = playersList.count * 3 + winnerIndex
        var currentStep = 0
        var interval: Double = 0.08
        
        func stepRoulette() {
            hapticTick.impactOccurred()
            activeRollIndex = currentStep % playersList.count
            currentStep += 1
            
            if currentStep < totalSteps {
                // Decelerate over time
                if currentStep > totalSteps - 6 {
                    interval += 0.07
                } else if currentStep > totalSteps - 12 {
                    interval += 0.03
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
                    stepRoulette()
                }
            } else {
                // Final stop on winner!
                activeRollIndex = winnerIndex
                winnerPlayer = playersList[winnerIndex]
                
                hapticSuccess.notificationOccurred(.success)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        drawState = .winnerAnnounced
                    }
                }
            }
        }
        
        stepRoulette()
    }
    
    private func proceedToTableOrdering() {
        guard let winner = winnerPlayer else { return }
        
        // Prepare remaining players to be reordered
        tableOrderRemaining = playersList.filter { $0.id != winner.id }
        
        withAnimation(.spring()) {
            drawState = .tableOrdering
        }
    }
    
    private func movePlayerUp(at index: Int) {
        guard index > 0 else { return }
        hapticImpact.impactOccurred()
        withAnimation(.spring()) {
            tableOrderRemaining.swapAt(index, index - 1)
        }
    }
    
    private func movePlayerDown(at index: Int) {
        guard index < tableOrderRemaining.count - 1 else { return }
        hapticImpact.impactOccurred()
        withAnimation(.spring()) {
            tableOrderRemaining.swapAt(index, index + 1)
        }
    }
    
    private func finalizeTableOrderAndGoToGames() {
        guard let winner = winnerPlayer else { return }
        
        // Reconstruct full ordered list: 1st place is winner, followed by table order
        var finalOrderedList: [Player] = [winner]
        finalOrderedList.append(contentsOf: tableOrderRemaining)
        
        gamePlayers = finalOrderedList
        hapticSuccess.notificationOccurred(.success)
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentScreen = .gameSelection
        }
    }
    
    private func resetAll() {
        speechManager.stopListening()
        withAnimation(.spring()) {
            playersList.removeAll()
            winnerPlayer = nil
            tableOrderRemaining.removeAll()
            drawState = .registering
            showingManualInput = false
            manualNameText = ""
        }
    }
}

// MARK: - Player Bubble View Component
struct PlayerBubbleView: View {
    let player: Player
    var onDelete: () -> Void
    
    var body: some View {
        ZStack {
            // Bubble background
            Circle()
                .fill(
                    RadialGradient(
                        colors: [player.color, player.color.opacity(0.85)],
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: 40
                    )
                )
                .frame(width: 76, height: 76)
                .overlay(
                    Circle().strokeBorder(Color.white.opacity(0.7), lineWidth: 2.5)
                )
                .shadow(color: player.color.opacity(0.6), radius: 12)
            
            // Name label
            Text(player.name)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 6)
            
            // Delete badge on top trailing
            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.9), Color.black.opacity(0.6))
            }
            .offset(x: 26, y: -26)
        }
    }
}
