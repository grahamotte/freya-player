import SwiftUI
import UIKit

#if os(tvOS)
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
            if state.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = state.errorMessage, state.items.isEmpty {
                VStack(spacing: 24) {
                    Text(errorMessage)
                        .foregroundStyle(AppTheme.secondaryText)

                    Button("Try Again") {
                        Task {
                            await state.loadItems(showSpinner: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LibraryPageCollectionView(
                    state: state,
                    onSelectRoute: { path.append($0) }
                )
            }
        }
        .background(AppBackground())
        .task(id: library.id) {
            state.update(library: library)
            await PollingLoop.run {
                await state.loadItems(showSpinner: state.items.isEmpty)
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
    private lazy var quickActionHandler = MediaItemQuickActionHandler(
        presenter: self,
        model: state.model,
        focusedItem: { [weak self] in self?.focusedQuickActionItem() },
        setOptimisticWatchStatus: { [weak self] itemID, isWatched in
            self?.setOptimisticWatchStatus(for: itemID, isWatched: isWatched)
        },
        clearOptimisticWatchStatus: { [weak self] itemID in
            self?.clearOptimisticWatchStatus(for: itemID)
        },
        refresh: { [weak self] in
            await self?.refreshItemsAfterQuickAction()
        }
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
        reloadDataPreservingScrollPosition(!didChangeLibrary)
        updateEmptyState()
        refreshHeader()
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        state.displayedItems.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: LibraryGridCell.reuseIdentifier,
            for: indexPath
        ) as! LibraryGridCell
        let item = state.displayedItems[indexPath.item]
        cell.configure(item: item, artworkURL: artworkURL(for: item), style: tileStyle)
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

    private func libraryWatchButtonView() -> AnyView? {
        guard let item = state.libraryWatchStatusItem else { return nil }

        return AnyView(
            MediaCollectionWatchStatusButton(
                model: state.model,
                item: item,
                reloadID: state.libraryWatchStatusReloadID,
                loadItems: { [weak self] in
                    guard let self else { return [] }
                    return try await self.state.watchTargets()
                },
                onUpdateFinished: { [weak self] in
                    await self?.refreshItemsAfterQuickAction()
                }
            )
        )
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

    private func setOptimisticWatchStatus(for itemID: String, isWatched: Bool) {
        state.setOptimisticWatchStatus(for: itemID, isWatched: isWatched)
        rebuildVisibleStatePreservingScroll()
    }

    private func clearOptimisticWatchStatus(for itemID: String) {
        state.clearOptimisticWatchStatus(for: itemID)
        rebuildVisibleStatePreservingScroll()
    }

    private func rebuildVisibleStatePreservingScroll() {
        guard isViewLoaded else { return }
        reloadDataPreservingScrollPosition(true)
        updateEmptyState()
        refreshHeader()
    }

    private func refreshItemsAfterQuickAction() async {
        await state.loadItems(showSpinner: false)
        rebuildVisibleStatePreservingScroll()
    }

    private func makeLayout() -> UICollectionViewLayout {
        let style = tileStyle
        let horizontalInset: CGFloat = 68
        let interItemSpacing: CGFloat = 44
        let lineSpacing: CGFloat = 32

        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.contentInsetsReference = .none
        configuration.boundarySupplementaryItems = [
            NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(224)),
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
            section.contentInsets = .init(top: 64, leading: horizontalInset, bottom: 0, trailing: horizontalInset)
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
    private let titleLabel = UILabel()
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
        imageView.adjustsImageWhenAncestorFocused = true
        imageView.overlayContentView.clipsToBounds = false

        iconView.tintColor = AppTheme.uiSecondaryText
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 44, weight: .semibold)

        placeholderStack.axis = .vertical
        placeholderStack.alignment = .center
        placeholderStack.spacing = 16
        placeholderStack.translatesAutoresizingMaskIntoConstraints = false
        placeholderStack.addArrangedSubview(iconView)
        imageView.overlayContentView.addSubview(placeholderStack)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        imageView.overlayContentView.addSubview(progressView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .preferredFont(forTextStyle: .callout).withTraits(.traitBold)
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentHuggingPriority(.required, for: .vertical)
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .preferredFont(forTextStyle: .footnote)
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

            placeholderStack.centerXAnchor.constraint(equalTo: imageView.overlayContentView.centerXAnchor),
            placeholderStack.centerYAnchor.constraint(equalTo: imageView.overlayContentView.centerYAnchor),

            progressView.leadingAnchor.constraint(equalTo: imageView.overlayContentView.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: imageView.overlayContentView.trailingAnchor),
            progressView.topAnchor.constraint(equalTo: imageView.overlayContentView.topAnchor),
            progressView.bottomAnchor.constraint(equalTo: imageView.overlayContentView.bottomAnchor),

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

    func configure(item: MediaItem, artworkURL: URL?, style: LibraryTileStyle) {
        self.style = style
        accessibilityLabel = item.title
        currentArtworkURL = artworkURL
        titleLabel.text = item.title
        subtitleLabel.text = item.subtitle
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
        imageTask?.cancel()
        imageTask = nil
        currentArtworkURL = nil
        imageView.image = Self.placeholderImage
        placeholderStack.isHidden = false
        progressView.setProgress(nil, isWatched: false)
    }
}

private final class LibraryPageHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "LibraryPageHeaderView"

    private let titleLabel = UILabel()
    private let countLabel = UILabel()
    private let filterButton = GlassMenuButton()
    private let sortButton = GlassMenuButton()
    private let watchButtonHostView = UIView()
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

        watchButtonHostView.translatesAutoresizingMaskIntoConstraints = false
        watchButtonHostView.backgroundColor = .clear
        watchButtonHostView.setContentHuggingPriority(.required, for: .horizontal)
        watchButtonHostView.setContentCompressionResistancePriority(.required, for: .horizontal)

        addSubview(titleLabel)
        addSubview(countLabel)
        addSubview(filterButton)
        addSubview(sortButton)
        addSubview(watchButtonHostView)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 68),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 44),

            countLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -68),
            countLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            filterButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 68),
            filterButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            filterButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),

            sortButton.leadingAnchor.constraint(equalTo: filterButton.trailingAnchor, constant: 24),
            sortButton.centerYAnchor.constraint(equalTo: filterButton.centerYAnchor),
            sortButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),
            sortButton.heightAnchor.constraint(equalTo: filterButton.heightAnchor),
            sortButton.trailingAnchor.constraint(lessThanOrEqualTo: watchButtonHostView.leadingAnchor, constant: -24),

            watchButtonHostView.leadingAnchor.constraint(greaterThanOrEqualTo: sortButton.trailingAnchor, constant: 24),
            watchButtonHostView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -68),
            watchButtonHostView.centerYAnchor.constraint(equalTo: filterButton.centerYAnchor),
            watchButtonHostView.heightAnchor.constraint(greaterThanOrEqualTo: filterButton.heightAnchor)
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

        if let watchButtonHostingController {
            watchButtonHostingController.rootView = watchButton
            return
        }

        let hostingController = UIHostingController(rootView: watchButton)
        if #available(tvOS 16.0, *) {
            hostingController.sizingOptions = [.intrinsicContentSize]
        }
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear
        hostingController.view.setContentHuggingPriority(.required, for: .horizontal)
        hostingController.view.setContentCompressionResistancePriority(.required, for: .horizontal)

        watchButtonHostView.addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: watchButtonHostView.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: watchButtonHostView.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: watchButtonHostView.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: watchButtonHostView.bottomAnchor)
        ])

        watchButtonHostingController = hostingController
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
            configuration.title = self.title
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
#endif
