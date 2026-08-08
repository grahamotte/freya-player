import UIKit
import SwiftUI

final class ArtworkProgressIndicatorView: UIView {
    private var hostingController: UIHostingController<WatchProgressCircle>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: WatchProgressCircle.size, height: WatchProgressCircle.size)
    }

    func setProgress(_ progress: Double?, isWatched: Bool) {
        let rootView = WatchProgressCircle(progress: progress, isWatched: isWatched)
        if let hostingController {
            hostingController.rootView = rootView
        } else {
            let hc = UIHostingController(rootView: rootView)
            hc.view.backgroundColor = .clear
            hc.view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(hc.view)
            NSLayoutConstraint.activate([
                hc.view.leadingAnchor.constraint(equalTo: leadingAnchor),
                hc.view.trailingAnchor.constraint(equalTo: trailingAnchor),
                hc.view.topAnchor.constraint(equalTo: topAnchor),
                hc.view.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
            hostingController = hc
        }
    }
}
