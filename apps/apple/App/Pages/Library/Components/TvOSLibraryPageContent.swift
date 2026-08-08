import SwiftUI
import UIKit

struct TvOSLibraryPageContent: View {
    @ObservedObject var model: AppModel
    let library: LibraryReference
    @Binding var path: [AppRoute]

    @StateObject private var state: LibraryPageState
    private let defaultsDidChange = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)

    init(model: AppModel, library: LibraryReference, path: Binding<[AppRoute]>) {
        self.model = model
        self.library = library
        _path = path
        _state = StateObject(wrappedValue: LibraryPageState(model: model, library: library))
    }

    var body: some View {
        Group {
            if state.isLoadingFirstPage {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LibraryPageCollectionView(
                    state: state,
                    onSelectRoute: { path.append($0) }
                )
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .background(AppBackground())
        .task(id: library.id) {
            state.update(library: library)
            await PollingLoop.run {
                state.refresh()
            }
        }
        .onReceive(defaultsDidChange) { _ in
            state.loadSavedControls()
        }
    }
}

private struct LibraryPageCollectionView: UIViewControllerRepresentable {
    let state: LibraryPageState
    let onSelectRoute: (AppRoute) -> Void

    func makeUIViewController(context: Context) -> LibraryPageCollectionViewController {
        LibraryPageCollectionViewController(
            state: state,
            onSelectRoute: onSelectRoute
        )
    }

    func updateUIViewController(_ viewController: LibraryPageCollectionViewController, context: Context) {
        viewController.update(state: state)
    }
}

private final class LibraryPageCollectionViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    private static let headerKind = "LibraryPageHeader"

    private let onSelectRoute: (AppRoute) -> Void

    private var state: LibraryPageState
    private var renderedLibrary: LibraryReference
    private var renderedItemIDs: [String] = []
    private lazy var quickActionHandler = MediaItemQuickActionHandler(
        presenter: self,
        model: state.model,
        focusedItem: { [weak self] in self?.focusedQuickActionItem() }
    )

    private lazy var collectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: makeLayout()
    )
    private let emptyLabel = UILabel()
    private let headerFocusGuide = UIFocusGuide()
    private var headerFocusGuideTopConstraint: NSLayoutConstraint?
    private var headerFocusGuideHeightConstraint: NSLayoutConstraint?

    init(
        state: LibraryPageState,
        onSelectRoute: @escaping (AppRoute) -> Void
    ) {
        self.state = state
        self.renderedLibrary = state.library
        self.onSelectRoute = onSelectRoute
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear
        view.clipsToBounds = false
        view.insetsLayoutMarginsFromSafeArea = false

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.clipsToBounds = false
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.remembersLastFocusedIndexPath = true
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.contentInset = .zero
        collectionView.insetsLayoutMarginsFromSafeArea = false
        collectionView.layoutMargins = .zero
        collectionView.register(LibraryGridCell.self, forCellWithReuseIdentifier: LibraryGridCell.reuseIdentifier)
        collectionView.register(
            LibraryPageHeaderView.self,
            forSupplementaryViewOfKind: Self.headerKind,
            withReuseIdentifier: LibraryPageHeaderView.reuseIdentifier
        )

        emptyLabel.font = .preferredFont(forTextStyle: .title3)
        emptyLabel.textColor = AppTheme.uiSecondaryText
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        collectionView.backgroundView = emptyLabel

        collectionView.addLayoutGuide(headerFocusGuide)
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        headerFocusGuideTopConstraint = headerFocusGuide.topAnchor.constraint(equalTo: collectionView.topAnchor)
        headerFocusGuideHeightConstraint = headerFocusGuide.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            headerFocusGuide.leadingAnchor.constraint(equalTo: collectionView.leadingAnchor),
            headerFocusGuide.trailingAnchor.constraint(equalTo: collectionView.trailingAnchor),
            headerFocusGuideTopConstraint!,
            headerFocusGuideHeightConstraint!
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateHeaderFocusGuide()
    }

    func update(state: LibraryPageState) {
        let didChangeLibrary = renderedLibrary != state.library
        self.state = state
        renderedLibrary = state.library

        guard isViewLoaded else { return }

        let newIDs = state.displayedItems.map(\.id)
        let structureChanged = newIDs != renderedItemIDs
        renderedItemIDs = newIDs

        if structureChanged {
            reloadDataPreservingScrollPosition(!didChangeLibrary)
        } else {
            reconfigureVisibleCells()
        }

        updateEmptyState()
        refreshHeader()
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        state.displayedItems.count
    }

    func indexTitles(for collectionView: UICollectionView) -> [String]? {
        let titles = indexTitleTargets.map(\.title)
        return titles.count > 1 ? titles : nil
    }

    func collectionView(_ collectionView: UICollectionView, indexPathForIndexTitle title: String, at index: Int) -> IndexPath {
        guard indexTitleTargets.indices.contains(index) else {
            return IndexPath(item: 0, section: 0)
        }

        return indexTitleTargets[index].indexPath
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: LibraryGridCell.reuseIdentifier,
            for: indexPath
        ) as! LibraryGridCell
        let item = state.displayedItems[indexPath.item]
        cell.configure(
            item: item,
            subtitle: item.libraryTileSubtitle(showsAddedAt: state.sort == .addedAt),
            artworkURL: artworkURL(for: item),
            style: tileStyle
        )
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: LibraryPageHeaderView.reuseIdentifier,
            for: indexPath
        ) as! LibraryPageHeaderView

        header.configure(
            title: state.library.title,
            countText: state.countText,
            selectedFilter: state.filter,
            selectedSort: state.sort,
            selectedSortOrder: state.sortOrder,
            playAllButton: libraryPlayAllButtonView(),
            watchButton: libraryWatchButtonView(),
            onFilterChange: { [weak self] filter in
                self?.setFilter(filter)
            },
            onSortChange: { [weak self] sort in
                self?.setSort(sort)
            },
            onSortOrderChange: { [weak self] order in
                self?.setSortOrder(order)
            }
        )
        return header
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onSelectRoute(state.displayedItems[indexPath.item].route)
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        quickActionHandler.pressesBegan(presses)
        super.pressesBegan(presses, with: event)
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if quickActionHandler.pressesEnded(presses) {
            return
        }

        super.pressesEnded(presses, with: event)
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        quickActionHandler.pressesCancelled(presses)
        super.pressesCancelled(presses, with: event)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateHeaderFocusGuide()
    }

    private var tileStyle: LibraryTileStyle {
        state.library.artworkStyle == .poster ? .poster : .landscape
    }

    private func artworkURL(for item: MediaItem) -> URL? {
        item.artwork.url(for: tileStyle.mediaArtworkStyle)
    }

    private var indexTitleTargets: [(title: String, indexPath: IndexPath)] {
        var seen = Set<String>()
        return state.displayedItems.enumerated().compactMap { offset, item in
            guard let title = indexTitle(for: item), seen.insert(title).inserted else { return nil }
            return (title, IndexPath(item: offset, section: 0))
        }
    }

    private func indexTitle(for item: MediaItem) -> String? {
        switch state.sort {
        case .addedAt:
            guard let addedAt = item.addedAt else { return "No Date" }
            return addedAtIndexTitle(Date(timeIntervalSince1970: TimeInterval(addedAt)))
        case .duration:
            guard let duration = item.durationMilliseconds else { return "No Runtime" }
            let minutes = duration / 60_000
            if minutes < 30 { return "<30m" }
            if minutes < 60 { return "30m" }
            return "\(minutes / 60)h"
        case .title:
            break
        }

        guard let scalar = item.title.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.first else { return nil }
        return CharacterSet.letters.contains(scalar) ? String(scalar).uppercased() : "#"
    }

    private func addedAtIndexTitle(_ date: Date) -> String {
        let days = max(Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0, 0) + 1
        if days < 7 { return "\(days)d" }
        if days < 31 { return "\(min((days - 1) / 7 + 1, 4))w" }
        if days < 365 { return "\(min((days - 1) / 30 + 1, 3))m" }
        if days < 1_095 { return "\(min((days - 1) / 365 + 1, 2))y" }
        return ">3y"
    }

    private func libraryWatchButtonView() -> AnyView? {
        guard let item = state.libraryWatchStatusItem else { return nil }

        return AnyView(
            MediaCollectionWatchStatusButton(
                model: state.model,
                libraryItem: item,
                libraryID: state.library.id
            )
        )
    }

    private func libraryPlayAllButtonView() -> AnyView {
        AnyView(MediaPlayAllButton(model: state.model, items: state.displayedPlayableItems))
    }

    private func setFilter(_ filter: LibraryPageFilter) {
        state.setFilter(filter)
        rebuildVisibleStatePreservingScroll()
    }

    private func setSort(_ sort: LibraryPageSort) {
        state.setSort(sort)
        rebuildVisibleStatePreservingScroll()
    }

    private func setSortOrder(_ order: LibraryPageSortOrder) {
        state.setSortOrder(order)
        rebuildVisibleStatePreservingScroll()
    }

    private func updateEmptyState() {
        emptyLabel.text = state.displayedItems.isEmpty ? state.filter.emptyStateText(for: state.library.itemTitle) : nil
    }

    private func focusedQuickActionItem() -> MediaItem? {
        guard let cell = collectionView.visibleCells.first(where: \.isFocused),
              let indexPath = collectionView.indexPath(for: cell)
        else {
            return nil
        }

        return state.displayedItems[indexPath.item]
    }

    private func refreshHeader() {
        let headerIndexPath = IndexPath(item: 0, section: 0)
        let header = collectionView.supplementaryView(
            forElementKind: Self.headerKind,
            at: headerIndexPath
        ) as? LibraryPageHeaderView

        header?.configure(
            title: state.library.title,
            countText: state.countText,
            selectedFilter: state.filter,
            selectedSort: state.sort,
            selectedSortOrder: state.sortOrder,
            playAllButton: libraryPlayAllButtonView(),
            watchButton: libraryWatchButtonView(),
            onFilterChange: { [weak self] filter in
                self?.setFilter(filter)
            },
            onSortChange: { [weak self] sort in
                self?.setSort(sort)
            },
            onSortOrderChange: { [weak self] order in
                self?.setSortOrder(order)
            }
        )

        updateHeaderFocusGuide()
    }

    private func updateHeaderFocusGuide() {
        let headerIndexPath = IndexPath(item: 0, section: 0)
        guard
            let header = collectionView.supplementaryView(
                forElementKind: Self.headerKind,
                at: headerIndexPath
            ) as? LibraryPageHeaderView
        else {
            headerFocusGuide.preferredFocusEnvironments = []
            headerFocusGuideHeightConstraint?.constant = 0
            return
        }

        headerFocusGuide.preferredFocusEnvironments = [header.focusTargetView]
        headerFocusGuideTopConstraint?.constant = header.frame.minY
        headerFocusGuideHeightConstraint?.constant = max(header.frame.height, 0)
    }

    private func reloadDataPreservingScrollPosition(_ shouldPreserveScrollPosition: Bool) {
        let contentOffset = collectionView.contentOffset

        UIView.performWithoutAnimation {
            collectionView.reloadData()
            collectionView.layoutIfNeeded()
        }

        guard shouldPreserveScrollPosition else { return }

        let minOffsetY = -collectionView.adjustedContentInset.top
        let maxOffsetY = max(
            collectionView.contentSize.height - collectionView.bounds.height + collectionView.adjustedContentInset.bottom,
            minOffsetY
        )
        let restoredOffset = CGPoint(
            x: contentOffset.x,
            y: min(max(contentOffset.y, minOffsetY), maxOffsetY)
        )

        collectionView.setContentOffset(restoredOffset, animated: false)
    }

    private func reconfigureVisibleCells() {
        for indexPath in collectionView.indexPathsForVisibleItems {
            guard indexPath.item < state.displayedItems.count,
                  let cell = collectionView.cellForItem(at: indexPath) as? LibraryGridCell
            else { continue }
            let item = state.displayedItems[indexPath.item]
            cell.configure(
                item: item,
                subtitle: item.libraryTileSubtitle(showsAddedAt: state.sort == .addedAt),
                artworkURL: artworkURL(for: item),
                style: tileStyle
            )
        }
    }

    private func rebuildVisibleStatePreservingScroll() {
        guard isViewLoaded else { return }
        reloadDataPreservingScrollPosition(true)
        updateEmptyState()
        refreshHeader()
    }

    private func makeLayout() -> UICollectionViewLayout {
        let style = tileStyle
        let horizontalInset: CGFloat = 68
        let interItemSpacing: CGFloat = 44
        let lineSpacing: CGFloat = 32

        let titleFont = UIFont.preferredFont(forTextStyle: .title1).withTraits(.traitBold)
        let titleHeight = ceil(titleFont.lineHeight)
        let titleTop: CGFloat = 44
        let gapBetweenTitleAndButtons: CGFloat = 28

        let measurementButton = GlassMenuButton()
        measurementButton.title = "Width"
        measurementButton.icon = UIImage(systemName: "line.3.horizontal.decrease")
        let buttonHeight = ceil(measurementButton.systemLayoutSizeFitting(
            CGSize(width: 300, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .fittingSizeLevel,
            verticalFittingPriority: .fittingSizeLevel
        ).height)

        let headerHeight = titleTop + titleHeight + gapBetweenTitleAndButtons + buttonHeight

        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.contentInsetsReference = .none
        configuration.boundarySupplementaryItems = [
            NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(headerHeight)),
                elementKind: Self.headerKind,
                alignment: .top
            )
        ]

        return UICollectionViewCompositionalLayout(sectionProvider: { _, environment in
            let columns = style.columns
            let availableWidth = environment.container.effectiveContentSize.width - (horizontalInset * 2)
            let cellWidth = style.cellWidth(for: availableWidth, spacing: interItemSpacing)
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .absolute(cellWidth),
                heightDimension: .absolute(style.cellHeight(for: cellWidth))
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let groupWidth = (cellWidth * CGFloat(columns)) + (interItemSpacing * CGFloat(columns - 1))
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .absolute(groupWidth),
                heightDimension: .absolute(style.cellHeight(for: cellWidth))
            )
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: columns)
            group.interItemSpacing = .fixed(interItemSpacing)

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = lineSpacing
            section.contentInsets = .init(top: 28, leading: horizontalInset, bottom: 0, trailing: horizontalInset)
            return section
        }, configuration: configuration)
    }
}

private enum LibraryTileStyle: Equatable {
    case poster
    case landscape

    var columns: Int {
        switch self {
        case .poster:
            return 4
        case .landscape:
            return 3
        }
    }

    var aspectRatio: CGFloat {
        switch self {
        case .poster:
            return 2 / 3
        case .landscape:
            return 16 / 9
        }
    }

    var placeholderIconName: String {
        switch self {
        case .poster:
            return "film.stack.fill"
        case .landscape:
            return "tv.fill"
        }
    }

    var mediaArtworkStyle: MediaArtworkStyle {
        switch self {
        case .poster:
            return .poster
        case .landscape:
            return .landscape
        }
    }

    func cellWidth(for availableWidth: CGFloat, spacing: CGFloat) -> CGFloat {
        floor((availableWidth - (spacing * CGFloat(columns - 1))) / CGFloat(columns))
    }

    func imageHeight(for width: CGFloat) -> CGFloat {
        floor(width / aspectRatio)
    }

    func cellHeight(for width: CGFloat) -> CGFloat {
        imageHeight(for: width) + textHeight
    }

    var textHeight: CGFloat {
        switch self {
        case .poster:
            return 112
        case .landscape:
            return 96
        }
    }
}

private final class LibraryGridCell: UICollectionViewCell {
    static let reuseIdentifier = "LibraryGridCell"
    private static let placeholderImage = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
        AppTheme.uiSurfaceFill.setFill()
        context.fill(CGRect(origin: .zero, size: CGSize(width: 8, height: 8)))
    }

    private let imageView = UIImageView()
    private let progressView = ArtworkProgressIndicatorView()
    private let placeholderStack = UIStackView()
    private let iconView = UIImageView()
    private let titleLabel = MarqueeLabel()
    private let subtitleLabel = UILabel()
    private var imageHeightConstraint: NSLayoutConstraint!
    private var imageTask: Task<Void, Never>?
    private var currentArtworkURL: URL?
    private var style: LibraryTileStyle = .landscape

    override init(frame: CGRect) {
        super.init(frame: frame)

        clipsToBounds = false
        contentView.clipsToBounds = false
        backgroundConfiguration = .clear()

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.clipsToBounds = false
        imageView.layer.cornerRadius = 24
        imageView.layer.cornerCurve = .continuous
        imageView.contentMode = .scaleAspectFill
        PlatformMetadata.configureFocusedImageView(imageView)

        iconView.tintColor = AppTheme.uiSecondaryText
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 44, weight: .semibold)

        placeholderStack.axis = .vertical
        placeholderStack.alignment = .center
        placeholderStack.spacing = 16
        placeholderStack.translatesAutoresizingMaskIntoConstraints = false
        placeholderStack.addArrangedSubview(iconView)
        PlatformMetadata.overlayContent(for: imageView).addSubview(placeholderStack)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        PlatformMetadata.overlayContent(for: imageView).addSubview(progressView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .preferredFont(forTextStyle: .callout).withTraits(.traitBold)
        titleLabel.setContentHuggingPriority(.required, for: .vertical)
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
        subtitleLabel.textColor = AppTheme.uiSecondaryText
        subtitleLabel.numberOfLines = 1
        subtitleLabel.setContentHuggingPriority(.required, for: .vertical)
        subtitleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        contentView.addSubview(imageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)

        imageHeightConstraint = imageView.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageHeightConstraint,

            placeholderStack.centerXAnchor.constraint(equalTo: PlatformMetadata.overlayContent(for: imageView).centerXAnchor),
            placeholderStack.centerYAnchor.constraint(equalTo: PlatformMetadata.overlayContent(for: imageView).centerYAnchor),

            progressView.trailingAnchor.constraint(equalTo: PlatformMetadata.overlayContent(for: imageView).trailingAnchor, constant: -WatchProgressCircle.padding),
            progressView.bottomAnchor.constraint(equalTo: PlatformMetadata.overlayContent(for: imageView).bottomAnchor, constant: -WatchProgressCircle.padding),
            progressView.widthAnchor.constraint(equalToConstant: WatchProgressCircle.size),
            progressView.heightAnchor.constraint(equalToConstant: WatchProgressCircle.size),

            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),

            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 1),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(item: MediaItem, subtitle: String?, artworkURL: URL?, style: LibraryTileStyle) {
        self.style = style
        accessibilityLabel = item.title
        currentArtworkURL = artworkURL
        titleLabel.text = item.title
        titleLabel.setMarqueeActive(isFocused)
        subtitleLabel.text = subtitle
        iconView.image = UIImage(systemName: style.placeholderIconName)
        progressView.setProgress(item.progress, isWatched: item.isWatched)
        imageView.image = Self.placeholderImage
        placeholderStack.isHidden = false
        imageHeightConstraint.constant = style.imageHeight(for: bounds.width)

        imageTask?.cancel()
        imageTask = nil

        guard let artworkURL else { return }

        if let image = ArtworkImageCache.shared.image(for: artworkURL) {
            imageView.image = image
            placeholderStack.isHidden = true
            return
        }

        imageTask = Task { [weak self] in
            guard let image = await ArtworkImageCache.shared.loadImage(from: artworkURL) else { return }
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self, self.currentArtworkURL == artworkURL else { return }
                self.imageView.image = image
                self.placeholderStack.isHidden = true
            }
        }
    }

    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
        imageHeightConstraint.constant = layoutAttributes.size.height - style.textHeight
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.setMarqueeActive(false)
        imageTask?.cancel()
        imageTask = nil
        currentArtworkURL = nil
        imageView.image = Self.placeholderImage
        placeholderStack.isHidden = false
        progressView.setProgress(nil, isWatched: false)
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        titleLabel.setMarqueeActive(isFocused)
    }
}

private final class LibraryPageHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "LibraryPageHeaderView"

    private let titleLabel = UILabel()
    private let countLabel = UILabel()
    private let filterButton = GlassMenuButton()
    private let sortButton = GlassMenuButton()
    private let shuffleButtonHostView = UIView()
    private let watchButtonHostView = UIView()
    private var shuffleButtonHostingController: UIHostingController<AnyView>?
    private var watchButtonHostingController: UIHostingController<AnyView>?
    private var onFilterChange: ((LibraryPageFilter) -> Void)?
    private var onSortChange: ((LibraryPageSort) -> Void)?

    var focusTargetView: UIView {
        filterButton
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        titleLabel.font = .preferredFont(forTextStyle: .title1).withTraits(.traitBold)
        titleLabel.textColor = AppTheme.uiPrimaryText
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        countLabel.font = .preferredFont(forTextStyle: .title3).withTraits(.traitBold)
        countLabel.textColor = AppTheme.uiSecondaryText
        countLabel.translatesAutoresizingMaskIntoConstraints = false

        filterButton.translatesAutoresizingMaskIntoConstraints = false
        filterButton.showsMenuAsPrimaryAction = true
        filterButton.icon = UIImage(systemName: "line.3.horizontal.decrease")

        sortButton.translatesAutoresizingMaskIntoConstraints = false
        sortButton.showsMenuAsPrimaryAction = true
        sortButton.icon = UIImage(systemName: "arrow.up.arrow.down")

        shuffleButtonHostView.translatesAutoresizingMaskIntoConstraints = false
        shuffleButtonHostView.backgroundColor = .clear
        shuffleButtonHostView.clipsToBounds = true
        shuffleButtonHostView.setContentHuggingPriority(.required, for: .horizontal)
        shuffleButtonHostView.setContentCompressionResistancePriority(.required, for: .horizontal)

        watchButtonHostView.translatesAutoresizingMaskIntoConstraints = false
        watchButtonHostView.backgroundColor = .clear
        watchButtonHostView.clipsToBounds = true
        watchButtonHostView.setContentHuggingPriority(.required, for: .horizontal)
        watchButtonHostView.setContentCompressionResistancePriority(.required, for: .horizontal)

        addSubview(titleLabel)
        addSubview(countLabel)
        addSubview(filterButton)
        addSubview(sortButton)
        addSubview(shuffleButtonHostView)
        addSubview(watchButtonHostView)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 68),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 44),

            countLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -68),
            countLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            filterButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 68),
            filterButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 28),
            filterButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),

            sortButton.leadingAnchor.constraint(equalTo: filterButton.trailingAnchor, constant: 24),
            sortButton.centerYAnchor.constraint(equalTo: filterButton.centerYAnchor),
            sortButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),
            sortButton.heightAnchor.constraint(equalTo: filterButton.heightAnchor),
            sortButton.trailingAnchor.constraint(lessThanOrEqualTo: shuffleButtonHostView.leadingAnchor, constant: -24),

            shuffleButtonHostView.leadingAnchor.constraint(greaterThanOrEqualTo: sortButton.trailingAnchor, constant: 24),
            shuffleButtonHostView.centerYAnchor.constraint(equalTo: filterButton.centerYAnchor),
            shuffleButtonHostView.heightAnchor.constraint(equalTo: filterButton.heightAnchor),

            watchButtonHostView.leadingAnchor.constraint(equalTo: shuffleButtonHostView.trailingAnchor, constant: 12),
            watchButtonHostView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -68),
            watchButtonHostView.centerYAnchor.constraint(equalTo: filterButton.centerYAnchor),
            watchButtonHostView.heightAnchor.constraint(equalTo: filterButton.heightAnchor),

            filterButton.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        title: String,
        countText: String,
        selectedFilter: LibraryPageFilter,
        selectedSort: LibraryPageSort,
        selectedSortOrder: LibraryPageSortOrder,
        playAllButton: AnyView,
        watchButton: AnyView?,
        onFilterChange: @escaping (LibraryPageFilter) -> Void,
        onSortChange: @escaping (LibraryPageSort) -> Void,
        onSortOrderChange: @escaping (LibraryPageSortOrder) -> Void
    ) {
        titleLabel.text = title
        countLabel.text = countText
        self.onFilterChange = onFilterChange
        self.onSortChange = onSortChange
        updateFilterButton(for: selectedFilter)
        updateSortButton(for: selectedSort, order: selectedSortOrder, onSortOrderChange: onSortOrderChange)
        updateHostedButton(playAllButton, in: shuffleButtonHostView, hostingController: &shuffleButtonHostingController)
        updateWatchButton(watchButton)
    }

    private func updateFilterButton(for filter: LibraryPageFilter) {
        filterButton.title = filter.title
        filterButton.menu = UIMenu(children: LibraryPageFilter.allCases.map { candidate in
            UIAction(title: candidate.title, state: candidate == filter ? .on : .off) { [weak self] _ in
                self?.onFilterChange?(candidate)
            }
        })
    }

    private func updateSortButton(
        for sort: LibraryPageSort,
        order: LibraryPageSortOrder,
        onSortOrderChange: @escaping (LibraryPageSortOrder) -> Void
    ) {
        sortButton.title = "\(sort.title) \(order.shortTitle)"
        sortButton.menu = UIMenu(children: [
            UIMenu(title: "Field", options: .displayInline, children: LibraryPageSort.allCases.map { candidate in
                UIAction(title: candidate.title, state: candidate == sort ? .on : .off) { [weak self] _ in
                    self?.onSortChange?(candidate)
                }
            }),
            UIMenu(title: "Order", options: .displayInline, children: LibraryPageSortOrder.allCases.map { candidate in
                UIAction(title: candidate.title, state: candidate == order ? .on : .off) { _ in
                    onSortOrderChange(candidate)
                }
            })
        ])
    }

    private func updateWatchButton(_ watchButton: AnyView?) {
        guard let watchButton else {
            watchButtonHostView.isHidden = true
            watchButtonHostingController?.rootView = AnyView(EmptyView())
            return
        }

        watchButtonHostView.isHidden = false

        updateHostedButton(watchButton, in: watchButtonHostView, hostingController: &watchButtonHostingController)
    }

    private func updateHostedButton(
        _ button: AnyView,
        in hostView: UIView,
        hostingController: inout UIHostingController<AnyView>?
    ) {
        if let hostingController {
            hostingController.rootView = button
            return
        }

        let nextHostingController = UIHostingController(rootView: button)
        if #available(tvOS 16.0, *) {
            nextHostingController.sizingOptions = [.intrinsicContentSize]
        }
        nextHostingController.view.translatesAutoresizingMaskIntoConstraints = false
        nextHostingController.view.backgroundColor = .clear
        nextHostingController.view.setContentHuggingPriority(.required, for: .horizontal)
        nextHostingController.view.setContentCompressionResistancePriority(.required, for: .horizontal)

        hostView.addSubview(nextHostingController.view)

        NSLayoutConstraint.activate([
            nextHostingController.view.leadingAnchor.constraint(equalTo: hostView.leadingAnchor),
            nextHostingController.view.trailingAnchor.constraint(equalTo: hostView.trailingAnchor),
            nextHostingController.view.topAnchor.constraint(equalTo: hostView.topAnchor),
            nextHostingController.view.bottomAnchor.constraint(equalTo: hostView.bottomAnchor)
        ])

        hostingController = nextHostingController
    }
}

private final class GlassMenuButton: UIButton {
    var title: String? {
        didSet { setNeedsUpdateConfiguration() }
    }
    var icon: UIImage? {
        didSet { setNeedsUpdateConfiguration() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
        layer.cornerRadius = 36
        layer.cornerCurve = .continuous
        configurationUpdateHandler = { [weak self] button in
            guard let self else { return }

            var configuration = UIButton.Configuration.plain()
            configuration.attributedTitle = self.title.map {
                AttributedString($0, attributes: AttributeContainer([
                    .font: UIFont.systemFont(ofSize: 24, weight: .semibold)
                ]))
            }
            configuration.image = self.icon
            configuration.imagePlacement = .leading
            configuration.imagePadding = 12
            configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
            configuration.baseForegroundColor = button.isFocused ? AppTheme.uiInverseText : AppTheme.uiPrimaryText
            configuration.contentInsets = .init(top: 16, leading: 28, bottom: 16, trailing: 28)
            button.configuration = configuration

            button.backgroundColor = button.isFocused ? AppTheme.uiPrimaryText : AppTheme.uiSurfaceBorder
            button.layer.borderColor = (button.isFocused ? UIColor.clear : AppTheme.uiPrimaryText.withAlphaComponent(0.28)).cgColor
            button.layer.borderWidth = button.isFocused ? 0 : 1
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else {
            return self
        }

        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
