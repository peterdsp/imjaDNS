import SwiftUI

struct AnimatedMeshBackground: View {
    @State private var phase: Double = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            MeshCanvas(time: now)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private struct MeshCanvas: View {
    let time: Double

    var body: some View {
        Canvas { context, size in
            drawBlob(context: context, size: size, color: Color(hex: "00D2FF").opacity(0.15),
                     xFactor: 0.3, yFactor: 0.2, xFreq: 0.3, yFreq: 0.4, xAmp: 0.15, yAmp: 0.1, radius: 0.45)
            drawBlob(context: context, size: size, color: Color(hex: "7B61FF").opacity(0.12),
                     xFactor: 0.7, yFactor: 0.5, xFreq: 0.25, yFreq: 0.35, xAmp: 0.1, yAmp: 0.15, radius: 0.5)
            drawBlob(context: context, size: size, color: Color(hex: "6C63FF").opacity(0.08),
                     xFactor: 0.5, yFactor: 0.8, xFreq: 0.2, yFreq: 0.3, xAmp: 0.2, yAmp: 0.1, radius: 0.4)
        }
    }

    private func drawBlob(
        context: GraphicsContext, size: CGSize,
        color: Color,
        xFactor: Double, yFactor: Double,
        xFreq: Double, yFreq: Double,
        xAmp: Double, yAmp: Double,
        radius: Double
    ) {
        let w = size.width
        let h = size.height
        let cx = w * (xFactor + xAmp * sin(time * xFreq))
        let cy = h * (yFactor + yAmp * cos(time * yFreq))
        let r = w * radius
        let center = CGPoint(x: cx, y: cy)

        let gradient = Gradient(colors: [color, color.opacity(0)])
        let shading = GraphicsContext.Shading.radialGradient(
            gradient, center: center, startRadius: 0, endRadius: r
        )
        context.fill(Path(CGRect(origin: .zero, size: size)), with: shading)
    }
}

struct PulsingRing: View {
    let color: Color
    let size: CGFloat

    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.6

    var body: some View {
        Circle()
            .stroke(color, lineWidth: 1.5)
            .frame(width: size, height: size)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false)) {
                    scale = 1.5
                    opacity = 0
                }
            }
    }
}
