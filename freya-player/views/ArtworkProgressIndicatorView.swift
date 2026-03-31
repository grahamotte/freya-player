import UIKit

final class ArtworkProgressIndicatorView: UIView {
    static let height: CGFloat = 8
    private static let inset: CGFloat = 12
    private static let badgeSize: CGFloat = 28

    private let trackView = UIView()
    private let fillView = UIView()
    private var progress: CGFloat = 0
    private let badgeView = UIView()
    private let checkmarkView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        isUserInteractionEnabled = false

        trackView.backgroundColor = .systemYellow.withAlphaComponent(0.3)
        trackView.isHidden = true
        addSubview(trackView)
        fillView.backgroundColor = .systemYellow
        trackView.addSubview(fillView)

        badgeView.backgroundColor = .systemYellow
        badgeView.isHidden = true
        addSubview(badgeView)

        checkmarkView.image = UIImage(systemName: "checkmark")
        checkmarkView.tintColor = .black
        checkmarkView.contentMode = .scaleAspectFit
        badgeView.addSubview(checkmarkView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let trackWidth = max(bounds.width - (Self.inset * 2), 0)
        let trackY = bounds.height - Self.inset - Self.height
        trackView.frame = CGRect(x: Self.inset, y: trackY, width: trackWidth, height: Self.height)
        trackView.layer.cornerRadius = Self.height / 2
        fillView.frame = CGRect(x: 0, y: 0, width: trackView.bounds.width * progress, height: trackView.bounds.height)
        fillView.layer.cornerRadius = trackView.bounds.height / 2

        let badgeOrigin = CGPoint(
            x: bounds.width - Self.inset - Self.badgeSize,
            y: bounds.height - Self.inset - Self.badgeSize
        )
        badgeView.frame = CGRect(origin: badgeOrigin, size: CGSize(width: Self.badgeSize, height: Self.badgeSize))
        badgeView.layer.cornerRadius = Self.badgeSize / 2
        checkmarkView.frame = badgeView.bounds.insetBy(dx: 7, dy: 7)
    }

    func setProgress(_ progress: Double?, isWatched: Bool) {
        let value = min(max(progress ?? 0, 0), 1)
        self.progress = CGFloat(value)
        trackView.isHidden = value <= 0 || isWatched
        badgeView.isHidden = !isWatched
        setNeedsLayout()
    }
}
