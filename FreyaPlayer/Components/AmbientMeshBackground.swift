import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct AmbientMeshBackground: View {
    let colors: [Color]
    var hueRotationRange: Double = 10
    var blurRadius: CGFloat = 120
    var saturation: Double = 0.95
    var opacity: Double = 0.74

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            MeshGradient(
                width: 4,
                height: 4,
                points: Self.meshPoints(at: time),
                colors: Self.meshColors(from: colors)
            )
            .hueRotation(.degrees(sin(time * 0.05) * hueRotationRange))
            .blur(radius: blurRadius)
            .saturation(saturation)
            .opacity(opacity)
            .drawingGroup(opaque: false, colorMode: .extendedLinear)
        }
    }

    static func randomColors() -> [Color] {
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

    private static func meshColors(from colors: [Color]) -> [Color] {
        guard !colors.isEmpty else { return randomColors() }
        guard colors.count < 16 else { return Array(colors.prefix(16)) }

        let pattern = [0, 1, 2, 3, 4, 1, 5, 2, 3, 0, 4, 5, 1, 2, 3, 4]
        return pattern.map { colors[$0 % colors.count] }
    }

    private static func meshPoints(at time: Double) -> [SIMD2<Float>] {
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

    private static func point(_ x: Float, _ y: Float, x xOffset: Float = 0, y yOffset: Float = 0) -> SIMD2<Float> {
        SIMD2(clamp(x + xOffset), clamp(y + yOffset))
    }

    private static func wave(_ time: Double, speed: Double, phase: Double, amplitude: Float) -> Float {
        Float(sin((time * speed) + phase)) * amplitude
    }

    private static func clamp(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }

    private static func wrappedHue(_ value: Double) -> Double {
        let wrapped = value.truncatingRemainder(dividingBy: 1)
        return wrapped >= 0 ? wrapped : wrapped + 1
    }
}

#if canImport(UIKit)
enum ArtworkPalette {
    private static let colorSpace = CGColorSpaceCreateDeviceRGB()
    private static let sampleWidth = 24
    private static let sampleHeight = 36
    private static let minDistance = 0.22
    private static let maxColors = 6

    static func colors(from image: UIImage) -> [Color] {
        guard let pixels = samplePixels(from: image) else { return [] }

        var buckets: [BucketKey: Bucket] = [:]

        for y in 0..<sampleHeight {
            for x in 0..<sampleWidth {
                let offset = ((y * sampleWidth) + x) * 4
                let alpha = Double(pixels[offset + 3]) / 255
                guard alpha > 0.98 else { continue }

                let red = Double(pixels[offset]) / 255
                let green = Double(pixels[offset + 1]) / 255
                let blue = Double(pixels[offset + 2]) / 255
                let hsv = hsv(red: red, green: green, blue: blue)

                guard hsv.brightness > 0.08 else { continue }

                let weight = prominenceWeight(x: x, y: y) * (0.35 + (hsv.saturation * 0.9))
                let key = BucketKey(
                    hue: Int(hsv.hue * 16),
                    saturation: Int(hsv.saturation * 4),
                    brightness: Int(hsv.brightness * 4)
                )

                buckets[key, default: .zero].add(
                    red: red,
                    green: green,
                    blue: blue,
                    saturation: hsv.saturation,
                    brightness: hsv.brightness,
                    weight: weight
                )
            }
        }

        let ranked = buckets.values.sorted { $0.score > $1.score }
        guard !ranked.isEmpty else { return [] }

        var selected: [SIMD3<Double>] = []

        for bucket in ranked {
            let candidate = bucket.color

            guard selected.allSatisfy({ colorDistance(candidate, $0) >= minDistance }) else { continue }
            selected.append(candidate)

            if selected.count == maxColors {
                break
            }
        }

        if selected.count < 3 {
            for bucket in ranked {
                let candidate = bucket.color
                guard selected.allSatisfy({ colorDistance(candidate, $0) > 0.1 }) else { continue }
                selected.append(candidate)

                if selected.count == 3 {
                    break
                }
            }
        }

        return selected.map { Color(uiColor: lifted($0)) }
    }

    private static func samplePixels(from image: UIImage) -> [UInt8]? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let cgImage = UIGraphicsImageRenderer(
            size: CGSize(width: sampleWidth, height: sampleHeight),
            format: format
        )
        .image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))
        }
        .cgImage

        guard let cgImage else { return nil }

        var pixels = [UInt8](repeating: 0, count: sampleWidth * sampleHeight * 4)
        guard let context = CGContext(
            data: &pixels,
            width: sampleWidth,
            height: sampleHeight,
            bitsPerComponent: 8,
            bytesPerRow: sampleWidth * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))
        return pixels
    }

    private static func hsv(red: Double, green: Double, blue: Double) -> (hue: Double, saturation: Double, brightness: Double) {
        let maxValue = max(red, green, blue)
        let minValue = min(red, green, blue)
        let delta = maxValue - minValue

        let saturation = maxValue == 0 ? 0 : delta / maxValue
        let brightness = maxValue

        guard delta > 0 else { return (0, saturation, brightness) }

        let hue: Double
        if maxValue == red {
            hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
        } else if maxValue == green {
            hue = ((blue - red) / delta) + 2
        } else {
            hue = ((red - green) / delta) + 4
        }

        return ((hue / 6).truncatingRemainder(dividingBy: 1).wrappedUnitInterval, saturation, brightness)
    }

    private static func prominenceWeight(x: Int, y: Int) -> Double {
        let normalizedX = (Double(x) + 0.5) / Double(sampleWidth)
        let normalizedY = (Double(y) + 0.5) / Double(sampleHeight)
        let distance = hypot(normalizedX - 0.5, normalizedY - 0.5) / 0.70710678118
        return 1 - (min(distance, 1) * 0.55)
    }

    private static func colorDistance(_ lhs: SIMD3<Double>, _ rhs: SIMD3<Double>) -> Double {
        let red = lhs.x - rhs.x
        let green = lhs.y - rhs.y
        let blue = lhs.z - rhs.z
        return sqrt((red * red) + (green * green) + (blue * blue))
    }

    private static func lifted(_ color: SIMD3<Double>) -> UIColor {
        let hsv = hsv(red: color.x, green: color.y, blue: color.z)
        let saturation = max(hsv.saturation, 0.18)
        let brightness = min(max(hsv.brightness, 0.3), 0.88)

        return UIColor(
            hue: hsv.hue,
            saturation: saturation,
            brightness: brightness,
            alpha: 1
        )
    }

    private struct BucketKey: Hashable {
        let hue: Int
        let saturation: Int
        let brightness: Int
    }

    private struct Bucket {
        static let zero = Bucket()

        var redTotal = 0.0
        var greenTotal = 0.0
        var blueTotal = 0.0
        var saturationTotal = 0.0
        var brightnessTotal = 0.0
        var weightTotal = 0.0

        mutating func add(
            red: Double,
            green: Double,
            blue: Double,
            saturation: Double,
            brightness: Double,
            weight: Double
        ) {
            redTotal += red * weight
            greenTotal += green * weight
            blueTotal += blue * weight
            saturationTotal += saturation * weight
            brightnessTotal += brightness * weight
            weightTotal += weight
        }

        var color: SIMD3<Double> {
            guard weightTotal > 0 else { return SIMD3(repeating: 0) }
            return SIMD3(redTotal / weightTotal, greenTotal / weightTotal, blueTotal / weightTotal)
        }

        var averageSaturation: Double {
            guard weightTotal > 0 else { return 0 }
            return saturationTotal / weightTotal
        }

        var averageBrightness: Double {
            guard weightTotal > 0 else { return 0 }
            return brightnessTotal / weightTotal
        }

        var score: Double {
            let darknessPenalty = averageBrightness < 0.16 ? 0.35 : 1
            return weightTotal * (0.45 + averageSaturation) * darknessPenalty
        }
    }
}

private extension Double {
    var wrappedUnitInterval: Double {
        let wrapped = truncatingRemainder(dividingBy: 1)
        return wrapped >= 0 ? wrapped : wrapped + 1
    }
}
#endif
