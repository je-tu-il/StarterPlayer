import SwiftUI

struct AtmosphericBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.03, blue: 0.08),
                    Color(red: 0.04, green: 0.08, blue: 0.16),
                    Color(red: 0.01, green: 0.01, blue: 0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [.cyan.opacity(0.20), .clear],
                center: .topLeading,
                startRadius: 30,
                endRadius: 360
            )
            
            RadialGradient(
                colors: [.purple.opacity(0.18), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 400
            )

            RadialGradient(
                colors: [.orange.opacity(0.15), .clear],
                center: .bottomTrailing,
                startRadius: 40,
                endRadius: 420
            )

            Canvas { context, size in
                for index in 0..<50 {
                    let x = CGFloat((index * 73) % 389) / 389 * size.width
                    let y = CGFloat((index * 127) % 541) / 541 * size.height
                    let rect = CGRect(x: x, y: y, width: 2.2, height: 2.2)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.10)))
                }
            }
        }
        .ignoresSafeArea()
    }
}
