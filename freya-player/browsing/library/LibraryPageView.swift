import SwiftUI
import UIKit

struct LibraryPageView: View {
    @ObservedObject var model: AppModel
    let library: PlexLibraryContext
    @Binding var path: [AppRoute]

    @State private var items: [PlexMediaItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                VStack(spacing: 24) {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)

                    Button("Try Again") {
                        Task {
                            await loadItems()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let summary = model.connectedSummary {
                LibraryPageCollectionView(
                    summary: summary,
                    library: library,
                    items: items,
                    onSelectRoute: { path.append($0) }
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(AppBackground())
        .task(id: library.id) {
            await loadItems()
        }
    }

    private func loadItems() async {
        isLoading = true
        errorMessage = nil

        do {
            items = try await model.plexLibraryItems(for: library)
            isLoading = false
        } catch {
            errorMessage = "Couldn't load this library."
            isLoading = false
        }
    }
}

private struct LibraryPageCollectionView: UIViewControllerRepresentable {
    let summary: PlexConnectionSummary
    let library: PlexLibraryContext
    let items: [PlexMediaItem]
    let onSelectRoute: (AppRoute) -> Void

    func makeUIViewController(context: Context) -> LibraryPageCollectionViewController {
        LibraryPageCollectionViewController(
            summary: summary,
            library: library,
            items: items,
            onSelectRoute: onSelectRoute
        )
    }

    func updateUIViewController(_ viewController: LibraryPageCollectionViewController, context: Context) {
        viewController.update(summary: summary, library: library, items: items)
    }
}

private final class LibraryPageCollectionViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    private static let headerKind = "LibraryPageHeader"

    private let onSelectRoute: (AppRoute) -> Void
    private let store = PlexSessionStore()

    private var summary: PlexConnectionSummary
    private var library: PlexLibraryContext
    private var items: [PlexMediaItem]
    private var filter: WatchFilter
    private var sort: LibrarySort
    private var sortOrder: LibrarySortOrder

    private lazy var collectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: makeLayout()
    )
    private let emptyLabel = UILabel()
    private let headerFocusGuide = UIFocusGuide()
    private var headerFocusGuideTopConstraint: NSLayoutConstraint?
    private var headerFocusGuideHeightConstraint: NSLayoutConstraint?

    init(
        summary: PlexConnectionSummary,
        library: PlexLibraryContext,
        items: [PlexMediaItem],
        onSelectRoute: @escaping (AppRoute) -> Void
    ) {
        self.summary = summary
        self.library = library
        self.items = items
        self.filter = Self.savedFilter(store: store, summary: summary, library: library)
        self.sort = Self.savedSort(store: store, summary: summary, library: library)
        self.sortOrder = Self.savedSortOrder(store: store, summary: summary, library: library, sort: self.sort)
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
        emptyLabel.textColor = .secondaryLabel
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

    func update(summary: PlexConnectionSummary, library: PlexLibraryContext, items: [PlexMediaItem]) {
        let didChangeLibrary = self.summary.serverID != summary.serverID || self.library.id != library.id
        self.summary = summary
        self.library = library
        self.items = items

        if didChangeLibrary {
            filter = Self.savedFilter(store: store, summary: summary, library: library)
            sort = Self.savedSort(store: store, summary: summary, library: library)
            sortOrder = Self.savedSortOrder(store: store, summary: summary, library: library, sort: sort)
        }

        guard isViewLoaded else { return }
        collectionView.setCollectionViewLayout(makeLayout(), animated: false)
        collectionView.reloadData()
        updateEmptyState()
        refreshHeader()
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        displayedItems.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: LibraryGridCell.reuseIdentifier,
            for: indexPath
        ) as! LibraryGridCell
        let item = displayedItems[indexPath.item]
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
            title: library.title,
            countText: countText,
            selectedFilter: filter,
            selectedSort: sort,
            selectedSortOrder: sortOrder,
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
        onSelectRoute(library.itemRoute(for: displayedItems[indexPath.item]))
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateHeaderFocusGuide()
    }

    private var displayedItems: [PlexMediaItem] {
        sort.items(from: items.filter { filter.matches($0) }, order: sortOrder)
    }

    private var tileStyle: LibraryTileStyle {
        library.usesPosterArtwork ? .poster : .landscape
    }

    private var countText: String {
        let count = displayedItems.count
        let itemName = library.itemName
        let suffix = count == 1 ? itemName : "\(itemName)s"
        return "\(count) \(suffix)"
    }

    private func artworkURL(for item: PlexMediaItem) -> URL? {
        item.artworkURL(
            baseURL: summary.serverURL,
            token: summary.serverToken,
            width: tileStyle.imageSize.width,
            height: tileStyle.imageSize.height,
            preferCoverArt: tileStyle == .landscape,
            allowBackdropFallback: tileStyle == .landscape
        )
    }

    private func setFilter(_ filter: WatchFilter) {
        guard self.filter != filter else { return }
        self.filter = filter
        store.setLibraryFilterRawValue(filter.rawValue, forLibraryID: library.id, serverID: summary.serverID)
        collectionView.reloadData()
        updateEmptyState()
        refreshHeader()
    }

    private func setSort(_ sort: LibrarySort) {
        guard self.sort != sort else { return }
        self.sort = sort
        store.setLibrarySortRawValue(sort.rawValue, forLibraryID: library.id, serverID: summary.serverID)
        collectionView.reloadData()
        refreshHeader()
    }

    private func setSortOrder(_ order: LibrarySortOrder) {
        guard sortOrder != order else { return }
        sortOrder = order
        store.setLibrarySortOrderRawValue(order.rawValue, forLibraryID: library.id, serverID: summary.serverID)
        collectionView.reloadData()
        refreshHeader()
    }

    private static func savedFilter(
        store: PlexSessionStore,
        summary: PlexConnectionSummary,
        library: PlexLibraryContext
    ) -> WatchFilter {
        guard
            let rawValue = store.libraryFilterRawValue(forLibraryID: library.id, serverID: summary.serverID),
            let filter = WatchFilter(rawValue: rawValue)
        else {
            return .all
        }

        return filter
    }

    private static func savedSort(
        store: PlexSessionStore,
        summary: PlexConnectionSummary,
        library: PlexLibraryContext
    ) -> LibrarySort {
        guard
            let rawValue = store.librarySortRawValue(forLibraryID: library.id, serverID: summary.serverID),
            let sort = LibrarySort(rawValue: rawValue)
        else {
            return .title
        }

        return sort
    }

    private static func savedSortOrder(
        store: PlexSessionStore,
        summary: PlexConnectionSummary,
        library: PlexLibraryContext,
        sort: LibrarySort
    ) -> LibrarySortOrder {
        guard
            let rawValue = store.librarySortOrderRawValue(forLibraryID: library.id, serverID: summary.serverID),
            let order = LibrarySortOrder(rawValue: rawValue)
        else {
            return sort.defaultOrder
        }

        return order
    }

    private func updateEmptyState() {
        emptyLabel.text = displayedItems.isEmpty ? filter.emptyStateText(for: library.itemName) : nil
    }

    private func refreshHeader() {
        let headerIndexPath = IndexPath(item: 0, section: 0)
        let header = collectionView.supplementaryView(
            forElementKind: Self.headerKind,
            at: headerIndexPath
        ) as? LibraryPageHeaderView

        header?.configure(
            title: library.title,
            countText: countText,
            selectedFilter: filter,
            selectedSort: sort,
            selectedSortOrder: sortOrder,
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
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: columns)
            group.interItemSpacing = .fixed(interItemSpacing)

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = lineSpacing
            section.contentInsets = .init(top: 64, leading: horizontalInset, bottom: 0, trailing: horizontalInset)
            return section
        }, configuration: configuration)
    }
}

private enum WatchFilter: Int, CaseIterable {
    case all
    case unwatched

    var title: String {
        switch self {
        case .all:
            return "All"
        case .unwatched:
            return "Unwatched"
        }
    }

    func matches(_ item: PlexMediaItem) -> Bool {
        switch self {
        case .all:
            return true
        case .unwatched:
            return !item.isWatched
        }
    }

    func emptyStateText(for itemName: String) -> String {
        let plural = "\(itemName)s"

        switch self {
        case .all:
            return "No \(plural)."
        case .unwatched:
            return "No unwatched \(plural)."
        }
    }
}

private enum LibrarySort: Int, CaseIterable {
    case title
    case addedAt
    case duration

    var title: String {
        switch self {
        case .title:
            return "Title"
        case .addedAt:
            return "Added At"
        case .duration:
            return "Duration"
        }
    }

    var defaultOrder: LibrarySortOrder {
        switch self {
        case .title:
            return .ascending
        case .addedAt, .duration:
            return .descending
        }
    }

    func items(from items: [PlexMediaItem], order: LibrarySortOrder) -> [PlexMediaItem] {
        items.sorted { lhs, rhs in
            switch self {
            case .title:
                return order.compare(lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending)
            case .addedAt:
                if let lhsAddedAt = lhs.addedAt, let rhsAddedAt = rhs.addedAt, lhsAddedAt != rhsAddedAt {
                    return order.compare(lhsAddedAt < rhsAddedAt)
                }
                if lhs.addedAt != nil || rhs.addedAt != nil {
                    return order.compare((lhs.addedAt ?? .min) < (rhs.addedAt ?? .min))
                }
                return order.compare(lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending)
            case .duration:
                if let lhsDuration = lhs.duration, let rhsDuration = rhs.duration, lhsDuration != rhsDuration {
                    return order.compare(lhsDuration < rhsDuration)
                }
                if lhs.duration != nil || rhs.duration != nil {
                    return order.compare((lhs.duration ?? .min) < (rhs.duration ?? .min))
                }
                return order.compare(lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending)
            }
        }
    }
}

private enum LibrarySortOrder: Int, CaseIterable {
    case ascending
    case descending

    var title: String {
        switch self {
        case .ascending:
            return "Ascending"
        case .descending:
            return "Descending"
        }
    }

    var shortTitle: String {
        switch self {
        case .ascending:
            return "Asc"
        case .descending:
            return "Desc"
        }
    }

    func compare(_ isAscending: Bool) -> Bool {
        switch self {
        case .ascending:
            return isAscending
        case .descending:
            return !isAscending
        }
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

    var imageSize: (width: Int, height: Int) {
        switch self {
        case .poster:
            return (480, 720)
        case .landscape:
            return (640, 360)
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
        UIColor.white.withAlphaComponent(0.08).setFill()
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

        iconView.tintColor = .secondaryLabel
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
        subtitleLabel.textColor = .secondaryLabel
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

    func configure(item: PlexMediaItem, artworkURL: URL?, style: LibraryTileStyle) {
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

        if let image = PlexArtworkImageCache.shared.image(for: artworkURL) {
            imageView.image = image
            placeholderStack.isHidden = true
            return
        }

        imageTask = Task { [weak self] in
            guard let image = await PlexArtworkImageCache.shared.loadImage(from: artworkURL) else { return }
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
    private var onFilterChange: ((WatchFilter) -> Void)?
    private var onSortChange: ((LibrarySort) -> Void)?

    var focusTargetView: UIView {
        filterButton
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        titleLabel.font = .preferredFont(forTextStyle: .title1).withTraits(.traitBold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        countLabel.font = .preferredFont(forTextStyle: .title3).withTraits(.traitBold)
        countLabel.textColor = .secondaryLabel
        countLabel.translatesAutoresizingMaskIntoConstraints = false

        filterButton.translatesAutoresizingMaskIntoConstraints = false
        filterButton.showsMenuAsPrimaryAction = true
        filterButton.icon = UIImage(systemName: "line.3.horizontal.decrease")

        sortButton.translatesAutoresizingMaskIntoConstraints = false
        sortButton.showsMenuAsPrimaryAction = true
        sortButton.icon = UIImage(systemName: "arrow.up.arrow.down")

        addSubview(titleLabel)
        addSubview(countLabel)
        addSubview(filterButton)
        addSubview(sortButton)

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
            sortButton.heightAnchor.constraint(equalTo: filterButton.heightAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        title: String,
        countText: String,
        selectedFilter: WatchFilter,
        selectedSort: LibrarySort,
        selectedSortOrder: LibrarySortOrder,
        onFilterChange: @escaping (WatchFilter) -> Void,
        onSortChange: @escaping (LibrarySort) -> Void,
        onSortOrderChange: @escaping (LibrarySortOrder) -> Void
    ) {
        titleLabel.text = title
        countLabel.text = countText
        self.onFilterChange = onFilterChange
        self.onSortChange = onSortChange
        updateFilterButton(for: selectedFilter)
        updateSortButton(for: selectedSort, order: selectedSortOrder, onSortOrderChange: onSortOrderChange)
    }

    private func updateFilterButton(for filter: WatchFilter) {
        filterButton.title = filter.title
        filterButton.menu = UIMenu(children: WatchFilter.allCases.map { candidate in
            UIAction(title: candidate.title, state: candidate == filter ? .on : .off) { [weak self] _ in
                self?.onFilterChange?(candidate)
            }
        })
    }

    private func updateSortButton(
        for sort: LibrarySort,
        order: LibrarySortOrder,
        onSortOrderChange: @escaping (LibrarySortOrder) -> Void
    ) {
        sortButton.title = "\(sort.title) \(order.shortTitle)"
        sortButton.menu = UIMenu(children: [
            UIMenu(title: "Field", options: .displayInline, children: LibrarySort.allCases.map { candidate in
                UIAction(title: candidate.title, state: candidate == sort ? .on : .off) { [weak self] _ in
                    self?.onSortChange?(candidate)
                }
            }),
            UIMenu(title: "Order", options: .displayInline, children: LibrarySortOrder.allCases.map { candidate in
                UIAction(title: candidate.title, state: candidate == order ? .on : .off) { _ in
                    onSortOrderChange(candidate)
                }
            })
        ])
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
            configuration.baseForegroundColor = button.isFocused ? .black : .white
            configuration.contentInsets = .init(top: 16, leading: 28, bottom: 16, trailing: 28)
            button.configuration = configuration

            button.backgroundColor = button.isFocused ? .white : UIColor.white.withAlphaComponent(0.12)
            button.layer.borderColor = (button.isFocused ? UIColor.clear : UIColor.white.withAlphaComponent(0.28)).cgColor
            button.layer.borderWidth = button.isFocused ? 0 : 1
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@MainActor
private final class PlexArtworkImageCache {
    static let shared = PlexArtworkImageCache()

    private let cache = NSCache<NSURL, UIImage>()

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func loadImage(from url: URL) async -> UIImage? {
        if let cached = image(for: url) {
            return cached
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return nil }
            cache.setObject(image, forKey: url as NSURL)
            return image
        } catch {
            return nil
        }
    }
}

private extension PlexMediaItem {
    var subtitle: String? {
        [year.map(String.init), runtimeText]
            .compactMap { $0 }
            .joined(separator: " • ")
            .nilIfEmpty
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

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
