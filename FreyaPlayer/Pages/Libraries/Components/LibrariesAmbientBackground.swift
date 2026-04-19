import SwiftUI

struct LibrariesAmbientBackground: View {
    @State private var colors = Self.makeColors()

    var body: some View {
        ZStack {
            AppBackground()

            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate

                MeshGradient(
                    width: 4,
                    height: 4,
                    points: meshPoints(at: time),
                    colors: colors
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

    private static func makeColors() -> [Color] {
        let baseHue = Double.random(in: 0...1)
        let hueSpread = Double.random(in: 0.45...0.8)
        let hueOffsets = [
            -0.34, -0.2, -0.08, 0.04,
            0.18, -0.12, 0.28, 0.42,
            0.1, 0.24, 0.54, 0.36,
            0.48, 0.64, 0.76, 0.9
        ]
        let saturations = [
            0.72, 0.78, 0.8, 0.76,
            0.82, 0.84, 0.76, 0.72,
            0.8, 0.74, 0.7, 0.78,
            0.82, 0.76, 0.72, 0.8
        ]
        let brightnesses = [
            0.98, 0.88, 0.93, 0.97,
            0.96, 0.86, 0.92, 0.95,
            0.94, 0.98, 0.9, 0.87,
            0.96, 0.89, 0.94, 0.97
        ]

        return hueOffsets.enumerated().map { index, offset in
            Color(
                hue: wrappedHue(baseHue + (offset * hueSpread)),
                saturation: saturations[index],
                brightness: brightnesses[index]
            )
        }
    }

    private static func wrappedHue(_ value: Double) -> Double {
        let wrapped = value.truncatingRemainder(dividingBy: 1)
        return wrapped >= 0 ? wrapped : wrapped + 1
    }
}
