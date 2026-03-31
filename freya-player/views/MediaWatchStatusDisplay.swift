import SwiftUI
import UIKit

enum MediaWatchStatusDisplay {
    static let uiColor = UIColor.systemYellow
    static let color = Color(uiColor: uiColor)
    static let iconName = "eye.fill"

    static func title(progress: Double?, isWatched: Bool) -> String {
        if isWatched {
            return "Watched"
        }

        let percent = progressPercent(progress)
        return percent == 0 ? "Unwatched" : "\(percent)%"
    }

    private static func progressPercent(_ progress: Double?) -> Int {
        let value = min(max(progress ?? 0, 0), 1)

        guard value > 0 else { return 0 }
        guard value < 1 else { return 100 }

        return min(max(Int((value * 100).rounded()), 1), 99)
    }
}
