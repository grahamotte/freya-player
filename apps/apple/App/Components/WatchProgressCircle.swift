import SwiftUI

struct WatchProgressCircle: View {
    let progress: Double?
    let isWatched: Bool

    private var displayProgress: Double {
        if isWatched { return 1 }
        return min(max(progress ?? 0, 0), 1)
    }

    var body: some View {
        if isWatched {
            ZStack {
                Circle()
                    .fill(MediaWatchStatusDisplay.color)

                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.black)
            }
            .frame(width: Self.size, height: Self.size)
        } else if displayProgress > 0 {
            PieSlice(progress: displayProgress)
                .fill(MediaWatchStatusDisplay.color)
                .frame(width: Self.size, height: Self.size)
        }
    }
}

extension WatchProgressCircle {
    static let size: CGFloat = 24
    static let padding: CGFloat = 12
}

private struct PieSlice: Shape {
    let progress: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        if progress <= 0 { return path }

        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * progress),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}
