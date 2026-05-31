import SwiftUI
import UIKit
import Combine

struct ContentView: View {
    @State private var touches: [TouchPoint] = []
    @State private var selectedTouchID: Int? = nil
    @State private var isSelectionLocked: Bool = false
    @State private var stableSince: Date? = nil
    @State private var signature: String = ""
    @State private var pulse: Bool = false

    private let selectionDelay: TimeInterval = 2.5
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            AtmosphericBackground()

            TouchCanvasView(touches: $touches)
                .ignoresSafeArea()
                .onChange(of: touches) { _, newTouches in
                    handleTouchChange(newTouches)
                }

            VStack(spacing: 12) {
                Text(headerText)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 18, y: 8)

                Text(subtitleText)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.68))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 72)
            .allowsHitTesting(false)

            ForEach(touches) { touch in
                TouchOrb(
                    touch: touch,
                    isSelected: selectedTouchID == touch.id,
                    isDimmed: isSelectionLocked && selectedTouchID != touch.id,
                    pulse: pulse
                )
                .position(touch.location)
                .animation(.spring(response: 0.34, dampingFraction: 0.72), value: touch.location)
                .animation(.easeInOut(duration: 0.42), value: selectedTouchID)
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onReceive(timer) { now in
            evaluateSelection(at: now)
        }
    }

    private var headerText: String {
        if isSelectionLocked { return "Chosen" }
        if touches.count > 1 { return "Hold still..." }
        return "Everyone touch in"
    }

    private var subtitleText: String {
        if isSelectionLocked { return "Lift all fingers to reset" }
        if touches.isEmpty { return "Place two or more fingers on the screen" }
        if touches.count == 1 { return "Add another finger to start the draw" }
        return "Selection begins after 2.5 seconds of steady touches"
    }

    private func handleTouchChange(_ newTouches: [TouchPoint]) {
        if newTouches.isEmpty {
            reset()
            return
        }

        guard !isSelectionLocked else { return }

        let newSignature = makeSignature(from: newTouches)
        if newSignature != signature {
            signature = newSignature
            stableSince = newTouches.count > 1 ? Date() : nil
        }
    }

    private func evaluateSelection(at now: Date) {
        guard !isSelectionLocked, touches.count > 1, let stableSince else { return }
        guard now.timeIntervalSince(stableSince) >= selectionDelay else { return }
        selectWinner()
    }

    private func selectWinner() {
        guard let winner = touches.randomElement() else { return }
        selectedTouchID = winner.id
        isSelectionLocked = true
        pulse = false

        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)

        withAnimation(.easeInOut(duration: 0.58).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }

    private func reset() {
        selectedTouchID = nil
        isSelectionLocked = false
        stableSince = nil
        signature = ""
        pulse = false
    }

    private func makeSignature(from touches: [TouchPoint]) -> String {
        touches
            .sorted { $0.id < $1.id }
            .map { touch in
                let x = Int((touch.location.x / 12).rounded())
                let y = Int((touch.location.y / 12).rounded())
                return "\(touch.id):\(x),\(y)"
            }
            .joined(separator: "|")
    }
}

struct TouchPoint: Identifiable, Equatable {
    let id: Int
    let location: CGPoint
    let color: Color
}

struct TouchCanvasView: UIViewRepresentable {
    @Binding var touches: [TouchPoint]

    func makeUIView(context: Context) -> MultiTouchView {
        let view = MultiTouchView()
        view.onTouchesChanged = { points in
            touches = points
        }
        return view
    }

    func updateUIView(_ uiView: MultiTouchView, context: Context) {
        uiView.onTouchesChanged = { points in
            touches = points
        }
    }
}

final class MultiTouchView: UIView {
    var onTouchesChanged: (([TouchPoint]) -> Void)?

    private var activeTouches: [UITouch: Int] = [:]
    private var nextID: Int = 1
    private let palette: [UIColor] = [
        UIColor(red: 0.07, green: 0.83, blue: 0.98, alpha: 1),
        UIColor(red: 1.00, green: 0.71, blue: 0.18, alpha: 1),
        UIColor(red: 1.00, green: 0.28, blue: 0.36, alpha: 1),
        UIColor(red: 0.48, green: 0.98, blue: 0.33, alpha: 1),
        UIColor(red: 0.72, green: 0.45, blue: 1.00, alpha: 1),
        UIColor(red: 0.16, green: 0.52, blue: 1.00, alpha: 1)
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches where activeTouches[touch] == nil {
            activeTouches[touch] = nextID
            nextID += 1
        }
        publish(event: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        publish(event: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { activeTouches.removeValue(forKey: touch) }
        publish(event: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { activeTouches.removeValue(forKey: touch) }
        publish(event: event)
    }

    private func publish(event: UIEvent?) {
        let allTouches = event?.allTouches?.filter { $0.phase != .ended && $0.phase != .cancelled } ?? []
        let points = allTouches.compactMap { touch -> TouchPoint? in
            guard let id = activeTouches[touch] else { return nil }
            let uiColor = palette[(id - 1) % palette.count]
            return TouchPoint(id: id, location: touch.location(in: self), color: Color(uiColor))
        }
        onTouchesChanged?(points.sorted { $0.id < $1.id })
    }
}

struct TouchOrb: View {
    let touch: TouchPoint
    let isSelected: Bool
    let isDimmed: Bool
    let pulse: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(touch.color.opacity(isDimmed ? 0.08 : 0.25))
                .frame(width: isSelected ? (pulse ? 188 : 150) : 106, height: isSelected ? (pulse ? 188 : 150) : 106)
                .blur(radius: 10)

            Circle()
                .strokeBorder(.white.opacity(isSelected ? 0.95 : 0.45), lineWidth: isSelected ? 5 : 2)
                .background(Circle().fill(touch.color.opacity(isDimmed ? 0.18 : 0.92)))
                .frame(width: isSelected ? (pulse ? 122 : 96) : 72, height: isSelected ? (pulse ? 122 : 96) : 72)
                .shadow(color: touch.color.opacity(isDimmed ? 0 : 0.75), radius: isSelected ? 34 : 18)

            if isSelected {
                Image(systemName: "crown.fill")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.32), radius: 8, y: 4)
            }
        }
        .opacity(isDimmed ? 0.16 : 1)
        .scaleEffect(isSelected ? 1.08 : 1)
        .allowsHitTesting(false)
    }
}

struct AtmosphericBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.02, green: 0.03, blue: 0.08), Color(red: 0.04, green: 0.08, blue: 0.16), Color(red: 0.01, green: 0.01, blue: 0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(colors: [.cyan.opacity(0.28), .clear], center: .topLeading, startRadius: 30, endRadius: 360)
            RadialGradient(colors: [.orange.opacity(0.20), .clear], center: .bottomTrailing, startRadius: 40, endRadius: 420)

            Canvas { context, size in
                for index in 0..<46 {
                    let x = CGFloat((index * 73) % 389) / 389 * size.width
                    let y = CGFloat((index * 127) % 541) / 541 * size.height
                    let rect = CGRect(x: x, y: y, width: 2.2, height: 2.2)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.12)))
                }
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
