import SwiftUI
import UIKit

enum MediaWatchStatusDisplay {
    static let uiColor = UIColor.systemYellow
    static let color = Color(uiColor: uiColor)
    static let iconName = "eye.fill"

    static func buttonColor(progress: Double?, isWatched: Bool) -> Color {
        Color(uiColor: blendedUIColor(progress: progress, isWatched: isWatched))
    }

    static func title(progress: Double?, isWatched: Bool) -> String {
        if isWatched {
            return "Watched"
        }

        let percent = progressPercent(progress)
        return percent == 0 ? "Unwatched" : "\(percent)%"
    }

    private static func progressPercent(_ progress: Double?) -> Int {
        let value = clampedProgress(progress, isWatched: false)

        guard value > 0 else { return 0 }
        guard value < 1 else { return 100 }

        return min(max(Int((value * 100).rounded()), 1), 99)
    }

    private static func blendedUIColor(progress: Double?, isWatched: Bool) -> UIColor {
        let amount = CGFloat(clampedProgress(progress, isWatched: isWatched))
        let start = UIColor.white.rgbaComponents
        let end = uiColor.rgbaComponents

        return UIColor(
            red: start.red + ((end.red - start.red) * amount),
            green: start.green + ((end.green - start.green) * amount),
            blue: start.blue + ((end.blue - start.blue) * amount),
            alpha: 1
        )
    }

    private static func clampedProgress(_ progress: Double?, isWatched: Bool) -> Double {
        if isWatched {
            return 1
        }

        return min(max(progress ?? 0, 0), 1)
    }
}

private extension UIColor {
    var rgbaComponents: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return (1, 1, 1, 1)
        }

        return (red, green, blue, alpha)
    }
}
