import SwiftUI

struct LibrariesAmbientBackground: View {
    var body: some View {
        ZStack {
            AppBackground()

            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate

                MeshGradient(
                    width: 4,
                    height: 4,
                    points: meshPoints(at: time),
                    colors: [
                        Color(red: 0.98, green: 0.28, blue: 0.54),
                        Color(red: 0.76, green: 0.22, blue: 0.82),
                        Color(red: 0.34, green: 0.29, blue: 0.96),
                        Color(red: 0.19, green: 0.52, blue: 1.0),

                        Color(red: 1.0, green: 0.56, blue: 0.23),
                        Color(red: 0.94, green: 0.2, blue: 0.42),
                        Color(red: 0.68, green: 0.23, blue: 0.84),
                        Color(red: 0.21, green: 0.62, blue: 1.0),

                        Color(red: 0.96, green: 0.36, blue: 0.27),
                        Color(red: 1.0, green: 0.27, blue: 0.56),
                        Color(red: 0.23, green: 0.85, blue: 0.58),
                        Color(red: 0.18, green: 0.73, blue: 0.88),

                        Color(red: 1.0, green: 0.58, blue: 0.24),
                        Color(red: 0.82, green: 0.41, blue: 0.22),
                        Color(red: 0.22, green: 0.86, blue: 0.56),
                        Color(red: 0.2, green: 0.54, blue: 1.0)
                    ]
                )
                .hueRotation(.degrees(sin(time * 0.05) * 10))
                .blur(radius: 120)
                .saturation(0.95)
                .opacity(0.74)
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

    private func meshPoints(at time: Double) -> [SIMD2<Float>] {
        [
            point(0.0, 0.0),
            point(0.33, 0.0, x: wave(time, speed: 0.05, phase: 0.2, amplitude: 0.08)),
            point(0.67, 0.0, x: wave(time, speed: 0.045, phase: 1.1, amplitude: 0.08)),
            point(1.0, 0.0),

            point(0.0, 0.33, y: wave(time, speed: 0.04, phase: 0.7, amplitude: 0.08)),
            point(
                0.33,
                0.33,
                x: wave(time, speed: 0.05, phase: 1.5, amplitude: 0.14),
                y: wave(time, speed: 0.045, phase: 2.1, amplitude: 0.12)
            ),
            point(
                0.67,
                0.33,
                x: wave(time, speed: 0.04, phase: 2.7, amplitude: 0.14),
                y: wave(time, speed: 0.05, phase: 0.9, amplitude: 0.12)
            ),
            point(1.0, 0.33, y: wave(time, speed: 0.045, phase: 1.8, amplitude: 0.08)),

            point(0.0, 0.67, y: wave(time, speed: 0.045, phase: 2.4, amplitude: 0.08)),
            point(
                0.33,
                0.67,
                x: wave(time, speed: 0.045, phase: 3.0, amplitude: 0.12),
                y: wave(time, speed: 0.04, phase: 1.2, amplitude: 0.14)
            ),
            point(
                0.67,
                0.67,
                x: wave(time, speed: 0.05, phase: 0.5, amplitude: 0.12),
                y: wave(time, speed: 0.045, phase: 2.9, amplitude: 0.14)
            ),
            point(1.0, 0.67, y: wave(time, speed: 0.04, phase: 0.1, amplitude: 0.08)),

            point(0.0, 1.0),
            point(0.33, 1.0, x: wave(time, speed: 0.045, phase: 2.0, amplitude: 0.08)),
            point(0.67, 1.0, x: wave(time, speed: 0.05, phase: 3.2, amplitude: 0.08)),
            point(1.0, 1.0)
        ]
    }

    private func point(_ x: Float, _ y: Float, x xOffset: Float = 0, y yOffset: Float = 0) -> SIMD2<Float> {
        SIMD2(clamp(x + xOffset), clamp(y + yOffset))
    }

    private func wave(_ time: Double, speed: Double, phase: Double, amplitude: Float) -> Float {
        Float(sin((time * speed) + phase)) * amplitude
    }

    private func clamp(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}
