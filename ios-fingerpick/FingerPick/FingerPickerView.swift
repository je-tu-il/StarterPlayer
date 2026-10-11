import SwiftUI
import UIKit
import Combine

struct FingerPickerView: View {
    @Binding var currentScreen: AppScreen
    @Binding var gamePlayers: [Player]
    
    @State private var markers: [TapMarker] = []
    @State private var selectedWinnerID: Int? = nil
    @State private var countdownRemaining: Double = 5.0
    @State private var isCountdownRunning: Bool = false
    @State private var nextMarkerID: Int = 1
    @State private var pulseWinner: Bool = false
    @State private var isLongPressing: Bool = false
    @State private var longPressProgress: CGFloat = 0.0
    
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    private let hapticImpact = UIImpactFeedbackGenerator(style: .medium)
    private let hapticSuccess = UINotificationFeedbackGenerator()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AtmosphericBackground()
                
                // Multi-tap detection canvas
                TapCanvasView(
                    onTap: { point in
                        handleCanvasTap(at: point, in: geometry.size)
                    },
                    onLongPressBegan: {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            isLongPressing = true
                            longPressProgress = 1.0
                        }
                    },
                    onLongPressEnded: { triggered in
                        withAnimation(.spring()) {
                            isLongPressing = false
                            longPressProgress = 0.0
                        }
                        if triggered {
                            hapticSuccess.notificationOccurred(.success)
                            proceedToGameMenu()
                        }
                    }
                )
                .ignoresSafeArea()
                
                // Markers Layer
                let diameter = pointDiameter(for: markers.count)
                ForEach(markers) { marker in
                    let isWinner = selectedWinnerID == marker.id
                    let isDimmed = selectedWinnerID != nil && !isWinner
                    
                    TouchOrbView(
                        marker: marker,
                        diameter: diameter,
                        isWinner: isWinner,
                        isDimmed: isDimmed,
                        pulse: pulseWinner
                    )
                    .position(marker.location)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: marker.location)
                    .animation(.easeInOut(duration: 0.3), value: diameter)
                    .animation(.easeInOut(duration: 0.4), value: isWinner)
                    .onTapGesture {
                        // Tapping directly on an orb removes it
                        removeMarker(id: marker.id)
                    }
                }
                
                // Top Switcher to Voice Mode
                HStack {
                    Button {
                        withAnimation(.spring()) {
                            currentScreen = .voicePick
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "mic.fill")
                            Text("Mode Vocal")
                        }
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.cyan)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(.ultraThinMaterial))
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                .frame(maxHeight: .infinity, alignment: .top)
                
                // Top Header / Countdown HUD
                VStack(spacing: 12) {
                    topStatusPill
                    
                    if markers.count >= 1 && selectedWinnerID == nil {
                        Text("\(markers.count) joueur\(markers.count > 1 ? "s" : "") en jeu • Taille adaptée")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(.ultraThinMaterial.opacity(0.3)))
                    }
                }
                .padding(.top, 96)
                .frame(maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)
                
                // Long-Press Visual Feedback Indicator (Charging Ring)
                if isLongPressing {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 6)
                            .frame(width: 90, height: 90)
                        
                        Circle()
                            .trim(from: 0, to: longPressProgress)
                            .stroke(
                                LinearGradient(colors: [.cyan, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .frame(width: 90, height: 90)
                            .rotationEffect(.degrees(-90))
                        
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                
                // Bottom Floating Controls
                VStack(spacing: 12) {
                    if let winnerID = selectedWinnerID, let winner = markers.first(where: { $0.id == winnerID }) {
                        // Winner Announcement Card
                        HStack(spacing: 14) {
                            Circle()
                                .fill(winner.color)
                                .frame(width: 38, height: 38)
                                .overlay(
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(.white)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Gagnant : Joueur \(winner.playerNumber)")
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("Prêt pour la partie !")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            Button {
                                restartCountdown()
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(Color.white.opacity(0.18)))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(red: 0.10, green: 0.13, blue: 0.22).opacity(0.95))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(winner.color.opacity(0.8), lineWidth: 1.5)
                                )
                        )
                        .shadow(color: winner.color.opacity(0.35), radius: 18)
                        .padding(.horizontal, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // Action Buttons Bar
                    HStack(spacing: 12) {
                        // Reset button
                        Button {
                            hapticImpact.impactOccurred()
                            resetAll()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.counterclockwise")
                                if markers.isEmpty {
                                    Text("Reset")
                                }
                            }
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                            .background(
                                Capsule().fill(.ultraThinMaterial)
                            )
                        }
                        
                        // Main CTA: Game Menu / Lancer avec ces joueurs
                        Button {
                            proceedToGameMenu()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "gamecontroller.fill")
                                    .font(.system(size: 15, weight: .bold))
                                Text(markers.count >= 2 ? "Jouer avec ces \(markers.count) joueurs" : "Menu des jeux")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(.black)
                            .padding(.horizontal, 20)
                            .frame(height: 44)
                            .background(
                                Capsule().fill(
                                    LinearGradient(colors: [Color.cyan, Color(red: 0.2, green: 0.9, blue: 0.6)], startPoint: .leading, endPoint: .trailing)
                                )
                            )
                        }
                    }
                    .padding(.bottom, 24)
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onReceive(timer) { _ in
            evaluateCountdown()
        }
    }
    
    // MARK: - Top Status Pill
    @ViewBuilder
    private var topStatusPill: some View {
        if let winnerID = selectedWinnerID, let winner = markers.first(where: { $0.id == winnerID }) {
            HStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .foregroundStyle(.yellow)
                Text("Joueur \(winner.playerNumber) a été choisi !")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .background(Capsule().fill(.ultraThinMaterial))
            .shadow(color: .black.opacity(0.3), radius: 10)
        } else if isCountdownRunning && markers.count >= 2 {
            HStack(spacing: 12) {
                // Circular mini-gauge
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.18), lineWidth: 3.5)
                        .frame(width: 26, height: 26)
                    Circle()
                        .trim(from: 0, to: CGFloat(countdownRemaining / 5.0))
                        .stroke(Color.cyan, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                        .frame(width: 26, height: 26)
                        .rotationEffect(.degrees(-90))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Tirage dans")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                        Text(String(format: "%.1fs", countdownRemaining))
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(.cyan)
                            .monospacedDigit()
                    }
                    Text("Nouveau clic = remise à 5s")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(Capsule().fill(.ultraThinMaterial))
            .shadow(color: .cyan.opacity(0.25), radius: 12)
        } else if markers.count == 1 {
            HStack(spacing: 8) {
                Image(systemName: "hand.tap.fill")
                    .foregroundStyle(.cyan)
                Text("Touchez pour ajouter d'autres joueurs")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Capsule().fill(.ultraThinMaterial))
        } else {
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.cyan)
                    Text("Chaque joueur touche 1 fois l'écran")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Text("Retirez le doigt ensuite • Appui long pour les jeux")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .background(Capsule().fill(.ultraThinMaterial))
        }
    }
    
    // MARK: - Point Scaling
    private func pointDiameter(for count: Int) -> CGFloat {
        switch count {
        case 0...4:
            return 84
        case 5...7:
            return 70
        case 8...11:
            return 56
        case 12...16:
            return 46
        default:
            return 38
        }
    }
    
    // MARK: - Tap & Countdown Logic
    private func handleCanvasTap(at point: CGPoint, in size: CGSize) {
        // Prevent registering taps too close to screen borders
        let clampedX = max(40, min(size.width - 40, point.x))
        let clampedY = max(110, min(size.height - 120, point.y))
        let location = CGPoint(x: clampedX, y: clampedY)
        
        let colorHex = AppPalette.hex(at: markers.count)
        let color = AppPalette.color(at: markers.count)
        
        let newMarker = TapMarker(
            id: nextMarkerID,
            location: location,
            color: color,
            colorHex: colorHex,
            playerNumber: nextMarkerID
        )
        nextMarkerID += 1
        
        hapticImpact.impactOccurred()
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
            markers.append(newMarker)
            // If winner was already picked, reset and restart
            selectedWinnerID = nil
            pulseWinner = false
            // Reset countdown to exactly 5.0 seconds upon new tap
            countdownRemaining = 5.0
            isCountdownRunning = markers.count >= 2
        }
    }
    
    private func removeMarker(id: Int) {
        hapticImpact.impactOccurred()
        withAnimation(.spring()) {
            markers.removeAll(where: { $0.id == id })
            if selectedWinnerID == id {
                selectedWinnerID = nil
                pulseWinner = false
            }
            if markers.count >= 2 {
                countdownRemaining = 5.0
                isCountdownRunning = true
            } else {
                isCountdownRunning = false
            }
        }
    }
    
    private func evaluateCountdown() {
        guard isCountdownRunning, markers.count >= 2, selectedWinnerID == nil else { return }
        
        countdownRemaining -= 0.05
        if countdownRemaining <= 0 {
            countdownRemaining = 0
            isCountdownRunning = false
            selectWinner()
        }
    }
    
    private func selectWinner() {
        guard let winner = markers.randomElement() else { return }
        selectedWinnerID = winner.id
        pulseWinner = false
        
        hapticSuccess.notificationOccurred(.success)
        
        withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
            pulseWinner = true
        }
    }
    
    private func restartCountdown() {
        withAnimation(.spring()) {
            selectedWinnerID = nil
            pulseWinner = false
            countdownRemaining = 5.0
            isCountdownRunning = markers.count >= 2
        }
    }
    
    private func resetAll() {
        withAnimation(.spring()) {
            markers.removeAll()
            selectedWinnerID = nil
            pulseWinner = false
            countdownRemaining = 5.0
            isCountdownRunning = false
            nextMarkerID = 1
        }
    }
    
    private func proceedToGameMenu() {
        // Convert tapped points to players if any
        if !markers.isEmpty {
            gamePlayers = markers.map { marker in
                Player(name: "Joueur \(marker.playerNumber)", colorHex: marker.colorHex)
            }
        } else if gamePlayers.isEmpty {
            // Default 4 players if none tapped
            gamePlayers = (1...4).map { idx in
                Player(name: "Joueur \(idx)", colorHex: AppPalette.hex(at: idx - 1))
            }
        }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentScreen = .gameSelection
        }
    }
}

// MARK: - Touch Orb Component
struct TouchOrbView: View {
    let marker: TapMarker
    let diameter: CGFloat
    let isWinner: Bool
    let isDimmed: Bool
    let pulse: Bool
    
    var body: some View {
        ZStack {
            // Outer Glow
            Circle()
                .fill(marker.color.opacity(isDimmed ? 0.04 : (isWinner ? 0.45 : 0.22)))
                .frame(
                    width: isWinner ? (pulse ? diameter * 2.3 : diameter * 1.8) : diameter * 1.4,
                    height: isWinner ? (pulse ? diameter * 2.3 : diameter * 1.8) : diameter * 1.4
                )
                .blur(radius: isWinner ? 16 : 8)
            
            // Winning pulse halo
            if isWinner {
                Circle()
                    .stroke(marker.color.opacity(pulse ? 0.9 : 0.3), lineWidth: pulse ? 4 : 2)
                    .frame(
                        width: pulse ? diameter * 2.0 : diameter * 1.3,
                        height: pulse ? diameter * 2.0 : diameter * 1.3
                    )
            }
            
            // Core Orb Body
            Circle()
                .fill(
                    RadialGradient(
                        colors: [marker.color, marker.color.opacity(0.85)],
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: diameter / 2
                    )
                )
                .frame(width: diameter, height: diameter)
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(isWinner ? 0.95 : 0.6), lineWidth: isWinner ? 4 : 2)
                )
                .shadow(color: marker.color.opacity(isDimmed ? 0 : 0.8), radius: isWinner ? 24 : 12)
            
            // Interior Content (Crown or Player Number)
            if isWinner {
                Image(systemName: "crown.fill")
                    .font(.system(size: diameter * 0.42, weight: .black))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
            } else {
                Text("\(marker.playerNumber)")
                    .font(.system(size: max(11, diameter * 0.38), weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
            }
        }
        .opacity(isDimmed ? 0.18 : 1.0)
        .scaleEffect(isWinner ? (pulse ? 1.15 : 1.05) : 1.0)
    }
}

// MARK: - UIKit Touch Canvas (Single Tap & Long Press)
struct TapCanvasView: UIViewRepresentable {
    var onTap: (CGPoint) -> Void
    var onLongPressBegan: () -> Void
    var onLongPressEnded: (Bool) -> Void
    
    func makeUIView(context: Context) -> CanvasUIView {
        let view = CanvasUIView()
        view.onTap = onTap
        view.onLongPressBegan = onLongPressBegan
        view.onLongPressEnded = onLongPressEnded
        return view
    }
    
    func updateUIView(_ uiView: CanvasUIView, context: Context) {
        uiView.onTap = onTap
        uiView.onLongPressBegan = onLongPressBegan
        uiView.onLongPressEnded = onLongPressEnded
    }
}

final class CanvasUIView: UIView {
    var onTap: ((CGPoint) -> Void)?
    var onLongPressBegan: (() -> Void)?
    var onLongPressEnded: ((Bool) -> Void)?
    
    private var longPressRecognizer: UILongPressGestureRecognizer!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGestures()
    }
    
    private func setupGestures() {
        backgroundColor = .clear
        isMultipleTouchEnabled = true
        
        longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressRecognizer.minimumPressDuration = 0.65
        addGestureRecognizer(longPressRecognizer)
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            onLongPressBegan?()
            onLongPressEnded?(true)
        case .cancelled, .failed:
            onLongPressEnded?(false)
        default:
            break
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        // If long press recognizer is actively recognizing, skip tap
        if longPressRecognizer.state == .began || longPressRecognizer.state == .changed {
            return
        }
        
        for touch in touches {
            let loc = touch.location(in: self)
            onTap?(loc)
        }
    }
}
