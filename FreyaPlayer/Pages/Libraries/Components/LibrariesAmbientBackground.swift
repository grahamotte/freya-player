import SwiftUI

struct LibrariesAmbientBackground: View {
    @State private var blobs: [ColorBlob] = (0..<4).map { _ in .randomBlob() }

    var body: some View {
        ZStack {
            AppBackground()

            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate

                Canvas { context, size in
                    for blob in blobs {
                        let x = (size.width * 0.5) + sin((time * blob.speedX) + blob.phaseX) * (size.width * 0.5)
                        let y = (size.height * 0.5) + cos((time * blob.speedY) + blob.phaseY) * (size.height * 0.5)
                        let rect = CGRect(
                            x: x - (blob.size / 2),
                            y: y - (blob.size / 2),
                            width: blob.size,
                            height: blob.size
                        )

                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(blob.color)
                        )
                    }
                }
                .blur(radius: 150)
                .saturation(0.95)
                .opacity(0.62)
                .drawingGroup(opaque: false, colorMode: .extendedLinear)
            }

            LinearGradient(
                colors: [
                    Color.black.opacity(0.08),
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.34)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [
                    Color.black.opacity(0.16),
                    .clear,
                    Color.black.opacity(0.14)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .ignoresSafeArea()
    }
}

private struct ColorBlob {
    let color: Color
    let size: CGFloat
    let speedX: Double
    let speedY: Double
    let phaseX: Double
    let phaseY: Double

    static func randomBlob() -> ColorBlob {
        let colors: [Color] = [
            Color(red: 1.0, green: 0.27, blue: 0.56),
            Color(red: 0.95, green: 0.18, blue: 0.42),
            Color(red: 0.72, green: 0.24, blue: 0.86),
            Color(red: 0.34, green: 0.28, blue: 0.96),
            Color(red: 0.2, green: 0.54, blue: 1.0),
            Color(red: 1.0, green: 0.58, blue: 0.24),
            Color(red: 0.22, green: 0.86, blue: 0.56)
        ]

        return ColorBlob(
            color: colors.randomElement() ?? .blue,
            size: CGFloat.random(in: 720...1200),
            speedX: Double.random(in: 0.02...0.05),
            speedY: Double.random(in: 0.02...0.05),
            phaseX: Double.random(in: 0...(2 * .pi)),
            phaseY: Double.random(in: 0...(2 * .pi))
        )
    }
}
