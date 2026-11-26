import SwiftUI

struct AtmosphericBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.13, green: 0.15, blue: 0.14),
                    Color(red: 0.19, green: 0.23, blue: 0.20),
                    Color(red: 0.12, green: 0.14, blue: 0.13)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color(red: 0.68, green: 0.78, blue: 0.85).opacity(0.15), .clear],
                center: .topLeading,
                startRadius: 30,
                endRadius: 360
            )
            
            RadialGradient(
                colors: [Color(red: 0.81, green: 0.83, blue: 0.67).opacity(0.12), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 400
            )

            RadialGradient(
                colors: [Color(red: 0.93, green: 0.65, blue: 0.57).opacity(0.10), .clear],
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
