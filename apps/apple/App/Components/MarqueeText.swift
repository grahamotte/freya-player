import SwiftUI
import UIKit

struct MarqueeText: View {
    let text: String
    let font: Font
    let isActive: Bool

    @State private var textWidth: CGFloat = 0
    @State private var viewWidth: CGFloat = 0
    @State private var isMarqueeVisible = false
    @State private var isAnimating = false

    private let gap: CGFloat = 32
    private let speed: CGFloat = 52.5

    var body: some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .opacity(isMarqueeVisible ? 0 : 1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { viewWidth = proxy.size.width }
                        .onChange(of: proxy.size.width) { _, width in viewWidth = width }
                }
            }
            .overlay(alignment: .leading) {
                if isMarqueeVisible {
                    HStack(spacing: gap) {
                        title
                        title
                    }
                    .offset(x: isAnimating ? -(textWidth + gap) : 0)
                    .frame(width: viewWidth, alignment: .leading)
                    .clipped()
                }
            }
            .overlay {
                title
                    .hidden()
                    .background {
                        GeometryReader { proxy in
                            Color.clear
                                .onAppear { textWidth = proxy.size.width }
                                .onChange(of: proxy.size.width) { _, width in textWidth = width }
                        }
                    }
            }
            .task(id: animationKey) {
                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) {
                    isMarqueeVisible = false
                    isAnimating = false
                }
                guard shouldMarquee else { return }
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }

                withTransaction(transaction) {
                    isMarqueeVisible = true
                }
                await Task.yield()
                guard !Task.isCancelled else { return }

                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }

    private var title: some View {
        Text(text)
            .font(font)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var duration: TimeInterval {
        max(2.7, TimeInterval((textWidth + gap) / speed))
    }

    private var shouldMarquee: Bool {
        isActive && textWidth > viewWidth
    }

    private var animationKey: String {
        "\(isActive)-\(text)-\(Int(textWidth))-\(Int(viewWidth))"
    }
}

final class MarqueeLabel: UIView {
    private let firstLabel = UILabel()
    private let secondLabel = UILabel()
    private var workItem: DispatchWorkItem?
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var offset: CGFloat = 0
    private var wantsMarquee = false
    private var isAnimating = false
    private let gap: CGFloat = 32
    private let speed: CGFloat = 52.5

    var text: String? {
        get { firstLabel.text }
        set {
            firstLabel.text = newValue
            secondLabel.text = newValue
            restartIfNeeded()
        }
    }

    var font: UIFont {
        get { firstLabel.font }
        set {
            firstLabel.font = newValue
            secondLabel.font = newValue
            restartIfNeeded()
        }
    }

    var textColor: UIColor {
        get { firstLabel.textColor }
        set {
            firstLabel.textColor = newValue
            secondLabel.textColor = newValue
        }
    }

    override var intrinsicContentSize: CGSize {
        firstLabel.intrinsicContentSize
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        firstLabel.lineBreakMode = .byTruncatingTail
        secondLabel.isHidden = true
        addSubview(firstLabel)
        addSubview(secondLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setMarqueeActive(_ isActive: Bool) {
        wantsMarquee = isActive
        workItem?.cancel()
        workItem = nil
        stop()
        guard isActive else { return }

        let item = DispatchWorkItem { [weak self] in self?.startIfNeeded() }
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: item)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutLabels()
    }

    private func startIfNeeded() {
        guard wantsMarquee, firstLabel.intrinsicContentSize.width > bounds.width else { return }
        isAnimating = true
        offset = 0
        lastTimestamp = 0
        firstLabel.lineBreakMode = .byClipping
        secondLabel.lineBreakMode = .byClipping
        secondLabel.isHidden = false
        layoutLabels()
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stop() {
        isAnimating = false
        displayLink?.invalidate()
        displayLink = nil
        offset = 0
        lastTimestamp = 0
        firstLabel.lineBreakMode = .byTruncatingTail
        secondLabel.isHidden = true
        setNeedsLayout()
    }

    private func restartIfNeeded() {
        invalidateIntrinsicContentSize()
        setNeedsLayout()
        guard wantsMarquee else { return }
        setMarqueeActive(true)
    }

    private func layoutLabels() {
        guard isAnimating else {
            firstLabel.frame = bounds
            secondLabel.frame = .zero
            return
        }

        let size = firstLabel.intrinsicContentSize
        firstLabel.frame = CGRect(x: offset, y: 0, width: size.width, height: bounds.height)
        secondLabel.frame = CGRect(x: offset + size.width + gap, y: 0, width: size.width, height: bounds.height)
    }

    @objc private func tick(_ displayLink: CADisplayLink) {
        guard wantsMarquee else {
            stop()
            return
        }

        if lastTimestamp == 0 {
            lastTimestamp = displayLink.timestamp
            return
        }

        let distance = firstLabel.bounds.width + gap
        offset -= CGFloat(displayLink.timestamp - lastTimestamp) * speed
        lastTimestamp = displayLink.timestamp

        if offset <= -distance {
            offset += distance
        }

        layoutLabels()
    }

    deinit {
        displayLink?.invalidate()
    }
}
