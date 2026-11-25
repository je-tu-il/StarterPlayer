import Foundation
import SwiftUI
import UIKit

struct FingerPickerView: View {
    @Binding var currentScreen: AppScreen
    @Binding var gamePlayers: [Player]
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("fingerpick.draws.v1") private var historyData = Data()
    @State private var simultaneous = true
    @State private var markers: [TapMarker] = []
    @State private var nextNumber = 1
    @State private var winner: TapMarker?
    @State private var countdown = 0
    @State private var countdownTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Mode tactile", selection: $simultaneous) {
                    Text("Doigts maintenus").tag(true)
                    Text("Touches successives").tag(false)
                }
                .pickerStyle(.segmented)
                .onChange(of: simultaneous) { reset() }

                Text(status)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 48)
                    .accessibilityAddTraits(.updatesFrequently)

                GeometryReader { proxy in
                    ZStack {
                        RoundedRectangle(cornerRadius: 24).fill(.quaternary)
                        MultiTouchCanvas(
                            simultaneous: simultaneous,
                            onAdd: { id, position in add(id: id, at: position, size: proxy.size) },
                            onRemove: { id in
                                guard winner == nil else { return }
                                markers.removeAll { $0.id == id }
                                scheduleDraw()
                            }
                        )
                        .accessibilityHidden(true)
                        ForEach(markers) { marker in
                            Circle()
                                .fill(marker.color)
                                .overlay {
                                    if winner?.id == marker.id {
                                        Image(systemName: "crown.fill").foregroundStyle(.black)
                                    } else {
                                        Text("\(marker.playerNumber)").foregroundStyle(.black)
                                    }
                                }
                                .frame(width: 48, height: 48)
                                .opacity(winner == nil || winner?.id == marker.id ? 1 : 0.25)
                                .position(marker.location)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }
                    .clipShape(.rect(cornerRadius: 24))
                }

                ViewThatFits {
                    HStack { actionButtons }
                    VStack { actionButtons }
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("Tirage tactile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Tirage", systemImage: "chevron.left") { currentScreen = .drawHome }
                }
            }
            .sensoryFeedback(.success, trigger: winner?.id) { _, new in new != nil }
        }
        .onChange(of: scenePhase) {
            if scenePhase != .active && winner == nil { reset() }
        }
        .onDisappear { countdownTask?.cancel() }
    }

    @ViewBuilder private var actionButtons: some View {
        Button("Recommencer", systemImage: "arrow.counterclockwise", action: reset)
        Button("Bibliothèque de scores", systemImage: "list.clipboard") {
            if winner != nil && gamePlayers.isEmpty { gamePlayers = winningRoster() }
            currentScreen = .gameSelection
        }
    }

    private var status: String {
        if let winner { return "Commence : \(markerName(winner))" }
        if countdown > 0 { return "Tirage dans \(countdown)…" }
        return simultaneous ? "Au moins deux joueurs gardent un doigt posé." : "Chacun touche la zone une fois."
    }

    private func markerName(_ marker: TapMarker) -> String {
        return "Joueur \(marker.playerNumber)"
    }

    private func add(id: Int, at position: CGPoint, size: CGSize) {
        guard winner == nil else { return }
        let margin = min(24, size.width / 2, size.height / 2)
        let point = CGPoint(x: min(max(margin, position.x), size.width - margin),
                            y: min(max(margin, position.y), size.height - margin))
        markers.append(TapMarker(id: id, location: point, color: AppPalette.color(at: nextNumber - 1),
                                 colorHex: AppPalette.hex(at: nextNumber - 1), playerNumber: nextNumber))
        nextNumber += 1
        scheduleDraw()
    }

    private func scheduleDraw() {
        countdownTask?.cancel()
        countdown = 0
        guard markers.count >= 2 else { return }
        countdown = simultaneous ? 2 : 5
        let seconds = countdown
        countdownTask = Task { @MainActor in
            for second in (1...seconds).reversed() {
                guard !Task.isCancelled else { return }
                countdown = second
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
            guard !Task.isCancelled, let selection = markers.randomElement() else { return }
            countdown = 0
            winner = selection
            let winnerName = markerName(selection)
            let record = DrawRecord(mode: .touch, roster: [], winner: nil,
                                    lines: ["Commence : \(winnerName)"])
            historyData = DrawHistory.appending(record, to: historyData)
        }
    }

    private func winningRoster() -> [Player] {
        var roster = markers.map {
            Player(name: "Joueur \($0.playerNumber)", colorHex: $0.colorHex)
        }
        if let position = markers.firstIndex(where: { $0.id == winner?.id }) {
            roster = Array(roster[position...] + roster[..<position])
        }
        return roster
    }

    private func reset() {
        countdownTask?.cancel()
        countdown = 0
        markers.removeAll()
        winner = nil
        nextNumber = 1
    }
}

private struct MultiTouchCanvas: UIViewRepresentable {
    let simultaneous: Bool
    let onAdd: (Int, CGPoint) -> Void
    let onRemove: (Int) -> Void

    func makeUIView(context: Context) -> TouchView {
        let view = TouchView()
        view.isMultipleTouchEnabled = true
        return view
    }

    func updateUIView(_ view: TouchView, context: Context) {
        view.simultaneous = simultaneous
        view.onAdd = onAdd
        view.onRemove = onRemove
    }

    final class TouchView: UIView {
        var simultaneous = true
        var onAdd: ((Int, CGPoint) -> Void)?
        var onRemove: ((Int) -> Void)?
        private var active: [ObjectIdentifier: Int] = [:]
        private var nextID = 0

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard simultaneous else { return }
            for touch in touches {
                let id = nextID
                nextID += 1
                active[ObjectIdentifier(touch)] = id
                onAdd?(id, touch.location(in: self))
            }
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            for touch in touches {
                if let id = active.removeValue(forKey: ObjectIdentifier(touch)) {
                    onRemove?(id)
                } else if !simultaneous {
                    onAdd?(nextID, touch.location(in: self))
                    nextID += 1
                }
            }
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            for touch in touches {
                if let id = active.removeValue(forKey: ObjectIdentifier(touch)) { onRemove?(id) }
            }
        }
    }
}
