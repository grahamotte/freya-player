import Combine
import SwiftUI
import UIKit

struct TvOSLibrariesPageContent: View {
    @ObservedObject var model: AppModel
    let server: ConnectedServer
    @Binding var path: [AppRoute]

    var body: some View {
        LibrariesCollectionView(
            model: model,
            server: server,
            onSelectRoute: { path.append($0) }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LibrariesAmbientBackground())
    }
}

private struct LibrariesCollectionView: UIViewControllerRepresentable {
    let model: AppModel
    let server: ConnectedServer
    let onSelectRoute: (AppRoute) -> Void

    func makeUIViewController(context: Context) -> LibrariesCollectionViewController {
        LibrariesCollectionViewController(
            model: model,
            server: server,
            onSelectRoute: onSelectRoute
        )
    }

    func updateUIViewController(_ viewController: LibrariesCollectionViewController, context: Context) {
        viewController.update(server: server)
    }
}

private final class LibrariesCollectionViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    private static let serverHeaderKind = "LibrariesServerHeader"

    private let model: AppModel
    private let onSelectRoute: (AppRoute) -> Void

    private var server: ConnectedServer
    private var sections: [LibrariesSection] = []
    private var selectedTitles: [String: String] = [:]
    private var openLibraryFocusedSections: Set<String> = []
    private var focusedSectionID: String?
    private var preferredFocusItemID: String?
    private var cacheSubscription: AnyCancellable?
    private var defaultsSubscription: AnyCancellable?
    private var refreshSubscription: AnyCancellable?
    private var isRefreshing = false
    private lazy var quickActionHandler = MediaItemQuickActionHandler(
        presenter: self,
        model: model,
        focusedItem: { [weak self] in self?.focusedQuickActionItem() }
    )

    private lazy var collectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: makeLayout()
    )

    init(
        model: AppModel,
        server: ConnectedServer,
        onSelectRoute: @escaping (AppRoute) -> Void
    ) {
        self.model = model
        self.server = server
        self.onSelectRoute = onSelectRoute
        self.isRefreshing = model.isRefreshingAllLibraries(server)
        super.init(nibName: nil, bundle: nil)
        sections = makeSections(from: server)
        selectedTitles = makeSelectedTitles(from: sections)

        cacheSubscription = model.libraryCache.snapshotDidChange
            .throttle(for: .milliseconds(250), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                self?.rebuildSectionsPreservingScrollPosition()
            }

        defaultsSubscription = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                self?.rebuildSectionsPreservingScrollPosition()
            }

        refreshSubscription = model.refreshTracker.$inFlight
            .sink { [weak self] inFlight in
                guard let self else { return }
                let nextIsRefreshing = inFlight.contains(.connection)
                    || self.server.libraries.contains { inFlight.contains(.library($0.id)) }
                guard self.isRefreshing != nextIsRefreshing else { return }
                self.isRefreshing = nextIsRefreshing
                self.rebuildSectionsPreservingScrollPosition()
            }
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

        collectionView.backgroundColor = .clear
        collectionView.clipsToBounds = false
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.remembersLastFocusedIndexPath = true
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.contentInset = .init(top: 12, left: 0, bottom: 64, right: 0)
        collectionView.insetsLayoutMarginsFromSafeArea = false
        collectionView.layoutMargins = .zero

        collectionView.register(LibraryTileCell.self, forCellWithReuseIdentifier: LibraryTileCell.reuseIdentifier)
        collectionView.register(LibrariesActionCell.self, forCellWithReuseIdentifier: LibrariesActionCell.reuseIdentifier)
        collectionView.register(
            LibrariesSectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: LibrariesSectionHeaderView.reuseIdentifier
        )
        collectionView.register(
            LibrariesSectionFooterView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
            withReuseIdentifier: LibrariesSectionFooterView.reuseIdentifier
        )
        collectionView.register(
            LibrariesServerHeaderView.self,
            forSupplementaryViewOfKind: Self.serverHeaderKind,
            withReuseIdentifier: LibrariesServerHeaderView.reuseIdentifier
        )

        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func update(server: ConnectedServer) {
        guard self.server != server else { return }
        let shouldPreserveScrollPosition = self.server.id == server.id
        self.server = server
        isRefreshing = model.isRefreshingAllLibraries(server)
        sections = makeSections(from: server)
        selectedTitles = makeSelectedTitles(from: sections)

        guard isViewLoaded else { return }
        reloadDataPreservingScrollPosition(shouldPreserveScrollPosition)
        requestPreferredFocusUpdateIfNeeded()
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        sections.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        sections[section].items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let item = sections[indexPath.section].items[indexPath.item]

        switch item.kind {
        case .manageServer, .refresh:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: LibrariesActionCell.reuseIdentifier,
                for: indexPath
            ) as! LibrariesActionCell
            cell.configure(
                title: item.title,
                isRefreshing: item.kind == .refresh(isRefreshing: true)
            )
            return cell

        case .openLibrary, .media:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: LibraryTileCell.reuseIdentifier,
                for: indexPath
            ) as! LibraryTileCell
            cell.configure(item: item)
            return cell
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        if kind == Self.serverHeaderKind {
            let view = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: LibrariesServerHeaderView.reuseIdentifier,
                for: indexPath
            ) as! LibrariesServerHeaderView
            view.title = server.serverName
            return view
        }

        let section = sections[indexPath.section]
        switch kind {
        case UICollectionView.elementKindSectionHeader:
            let view = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: LibrariesSectionHeaderView.reuseIdentifier,
                for: indexPath
            ) as! LibrariesSectionHeaderView
            view.title = section.title
            return view

        default:
            let view = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: LibrariesSectionFooterView.reuseIdentifier,
                for: indexPath
            ) as! LibrariesSectionFooterView
            view.title = footerTitle(for: section)
            return view
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = sections[indexPath.section].items[indexPath.item]
        handlePrimaryAction(for: item)
    }

    func collectionView(_ collectionView: UICollectionView, canFocusItemAt indexPath: IndexPath) -> Bool {
        sections[indexPath.section].items[indexPath.item].kind != .refresh(isRefreshing: true)
    }

    func indexPathForPreferredFocusedView(in collectionView: UICollectionView) -> IndexPath? {
        guard let targetItemID = preferredFocusItemID else { return nil }

        for (sectionIndex, section) in sections.enumerated() {
            if let itemIndex = section.items.firstIndex(where: { $0.id == targetItemID }) {
                return IndexPath(item: itemIndex, section: sectionIndex)
            }
        }

        preferredFocusItemID = nil
        return nil
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

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)

        if
            let indexPath = indexPath(for: context.nextFocusedView),
            sections.indices.contains(indexPath.section)
        {
            let section = sections[indexPath.section]
            preferredFocusItemID = nil
            if case .library = section.kind {
                focusedSectionID = section.id

                if section.emptyMessage == nil {
                    let item = section.items[indexPath.item]
                    if item.kind == .openLibrary {
                        openLibraryFocusedSections.insert(section.id)
                    } else {
                        openLibraryFocusedSections.remove(section.id)
                        selectedTitles[section.id] = item.title
                    }
                }
            } else {
                focusedSectionID = nil
                openLibraryFocusedSections.removeAll()
            }
        } else {
            focusedSectionID = nil
            openLibraryFocusedSections.removeAll()
        }

        coordinator.addCoordinatedAnimations {
            self.refreshVisibleFooters()
        }
    }

    private func makeLayout() -> UICollectionViewLayout {
        let horizontalInset: CGFloat = 48
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.contentInsetsReference = .none
        configuration.interSectionSpacing = 40
        configuration.boundarySupplementaryItems = [
            NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(144)),
                elementKind: Self.serverHeaderKind,
                alignment: .top
            )
        ]

        return UICollectionViewCompositionalLayout(sectionProvider: { [weak self] sectionIndex, environment in
            guard let self else { return nil }
            let section = sections[sectionIndex]

            switch section.kind {
            case .library(let style):
                let cellSize = style.cellSize(
                    for: environment.container.effectiveContentSize.width - (horizontalInset * 2)
                )
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .absolute(cellSize.width),
                    heightDimension: .absolute(cellSize.height)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
                let layoutSection = NSCollectionLayoutSection(group: group)
                layoutSection.interGroupSpacing = 44
                layoutSection.orthogonalScrollingBehavior = .continuousGroupLeadingBoundary
                layoutSection.contentInsets = .init(top: 8, leading: horizontalInset, bottom: 8, trailing: horizontalInset)

                let headerSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .absolute(56)
                )
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: headerSize,
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top
                )
                let footerSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .absolute(56)
                )
                let footer = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: footerSize,
                    elementKind: UICollectionView.elementKindSectionFooter,
                    alignment: .bottom
                )
                layoutSection.boundarySupplementaryItems = [header, footer]
                return layoutSection

            case .manage:
                let buttonWidth: CGFloat = 360
                let buttonSpacing: CGFloat = 24
                let buttonCount = section.items.count
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .absolute(buttonWidth),
                    heightDimension: .absolute(72)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupWidth = (buttonWidth * CGFloat(buttonCount)) + (buttonSpacing * CGFloat(max(buttonCount - 1, 0)))
                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .absolute(groupWidth),
                    heightDimension: .absolute(72)
                )
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: groupSize,
                    subitem: item,
                    count: buttonCount
                )
                group.interItemSpacing = .fixed(buttonSpacing)
                let layoutSection = NSCollectionLayoutSection(group: group)
                layoutSection.contentInsets = .init(top: 28, leading: horizontalInset, bottom: 36, trailing: horizontalInset)
                return layoutSection
            }
        }, configuration: configuration)
    }

    private func makeSections(from server: ConnectedServer) -> [LibrariesSection] {
        let projection = LibrariesHomeProjection(server: server, cache: model.libraryCache)
        let librarySections = projection.shelves.map { shelf in
            let style = shelf.artworkStyle == .poster ? LibrariesShelfStyle.poster : .wide
            let openItem = LibrariesItem(
                id: "\(shelf.id)-open",
                title: "Open Library",
                artworkURL: nil,
                progress: nil,
                isWatched: false,
                mediaItem: nil,
                route: shelf.libraryRoute,
                style: style,
                kind: .openLibrary,
                iconName: "arrow.right"
            )

            let mediaItems = shelf.previewItems.map { item in
                LibrariesItem(
                    id: item.id,
                    title: item.title,
                    artworkURL: item.artwork.url(for: style.mediaArtworkStyle),
                    progress: item.progress,
                    isWatched: item.isWatched,
                    mediaItem: item,
                    route: item.route,
                    style: style,
                    kind: .media,
                    iconName: style.placeholderIconName
                )
            }

            return LibrariesSection(
                id: shelf.id,
                title: shelf.title,
                kind: .library(style),
                items: [openItem] + mediaItems,
                defaultSelectionTitle: shelf.title,
                emptyMessage: shelf.emptyMessage
            )
        }

        let manageSection = LibrariesSection(
            id: "manage-server",
            title: nil,
            kind: .manage,
            items: [
                LibrariesItem(
                    id: "refresh",
                    title: isRefreshing ? "Refreshing..." : "Refresh",
                    artworkURL: nil,
                    progress: nil,
                    isWatched: false,
                    mediaItem: nil,
                    route: nil,
                    style: .wide,
                    kind: .refresh(isRefreshing: isRefreshing),
                    iconName: nil
                ),
                LibrariesItem(
                    id: "manage-server",
                    title: "Manage",
                    artworkURL: nil,
                    progress: nil,
                    isWatched: false,
                    mediaItem: nil,
                    route: projection.manageRoute,
                    style: .wide,
                    kind: .manageServer,
                    iconName: nil
                ),
                LibrariesItem(
                    id: "about",
                    title: "About",
                    artworkURL: nil,
                    progress: nil,
                    isWatched: false,
                    mediaItem: nil,
                    route: .about,
                    style: .wide,
                    kind: .manageServer,
                    iconName: nil
                )
            ],
            defaultSelectionTitle: nil,
            emptyMessage: nil
        )

        return librarySections + [manageSection]
    }

    private func makeSelectedTitles(from sections: [LibrariesSection]) -> [String: String] {
        sections.reduce(into: [:]) { titles, section in
            guard let title = section.defaultSelectionTitle, section.emptyMessage == nil else { return }
            titles[section.id] = title
        }
    }

    private func footerTitle(for section: LibrariesSection) -> String? {
        if let emptyMessage = section.emptyMessage {
            return emptyMessage
        }

        guard section.id == focusedSectionID else { return nil }
        guard !openLibraryFocusedSections.contains(section.id) else { return nil }
        return selectedTitles[section.id] ?? section.defaultSelectionTitle
    }

    private func refreshVisibleFooters() {
        for sectionIndex in sections.indices {
            let footerIndexPath = IndexPath(item: 0, section: sectionIndex)
            let footer = collectionView.supplementaryView(
                forElementKind: UICollectionView.elementKindSectionFooter,
                at: footerIndexPath
            ) as? LibrariesSectionFooterView
            footer?.title = footerTitle(for: sections[sectionIndex])
        }
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

    private func indexPath(for focusedView: UIView?) -> IndexPath? {
        var view = focusedView

        while let current = view {
            if let cell = current as? UICollectionViewCell {
                return collectionView.indexPath(for: cell)
            }

            view = current.superview
        }

        return nil
    }

    private func handlePrimaryAction(for item: LibrariesItem) {
        if item.kind == .refresh(isRefreshing: false) {
            model.refreshAllLibraries(server)
            return
        }

        guard let route = item.route else { return }
        onSelectRoute(route)
    }

    private func focusedQuickActionItem() -> MediaItem? {
        guard let cell = collectionView.visibleCells.first(where: \.isFocused),
              let indexPath = collectionView.indexPath(for: cell)
        else {
            return nil
        }

        let item = sections[indexPath.section].items[indexPath.item]
        guard case .media = item.kind else { return nil }
        return item.mediaItem
    }

    private func rebuildSectionsPreservingScrollPosition(preferredFocusItemID: String? = nil) {
        let previousReloadKey = reloadKey(for: sections)
        let nextSections = makeSections(from: server)
        let nextReloadKey = reloadKey(for: nextSections)

        self.preferredFocusItemID = preferredFocusItemID
        sections = nextSections
        selectedTitles = makeSelectedTitles(from: sections)

        guard isViewLoaded else { return }

        if previousReloadKey == nextReloadKey {
            reconfigureVisibleCells()
            refreshVisibleFooters()
            requestPreferredFocusUpdateIfNeeded()
            return
        }

        reloadDataPreservingScrollPosition(true)
        requestPreferredFocusUpdateIfNeeded()
    }

    private func requestPreferredFocusUpdateIfNeeded() {
        guard preferredFocusItemID != nil else { return }
        collectionView.setNeedsFocusUpdate()
        collectionView.updateFocusIfNeeded()
    }

    private func reconfigureVisibleCells() {
        for indexPath in collectionView.indexPathsForVisibleItems {
            guard sections.indices.contains(indexPath.section),
                  sections[indexPath.section].items.indices.contains(indexPath.item)
            else {
                continue
            }

            let item = sections[indexPath.section].items[indexPath.item]
            switch collectionView.cellForItem(at: indexPath) {
            case let cell as LibraryTileCell:
                cell.configure(item: item)
            case let cell as LibrariesActionCell:
                cell.configure(
                    title: item.title,
                    isRefreshing: item.kind == .refresh(isRefreshing: true)
                )
            default:
                continue
            }
        }
    }

    private func reloadKey(for sections: [LibrariesSection]) -> [LibrariesSectionReloadKey] {
        sections.map { section in
            LibrariesSectionReloadKey(
                id: section.id,
                kind: section.kind,
                itemKeys: section.items.map {
                    LibrariesItemReloadKey(
                        id: $0.id,
                        artworkURL: $0.artworkURL,
                        route: $0.route,
                        style: $0.style,
                        kind: $0.kind,
                        iconName: $0.iconName
                    )
                }
            )
        }
    }
}

private struct LibrariesSection: Hashable {
    let id: String
    let title: String?
    let kind: LibrariesSectionKind
    let items: [LibrariesItem]
    let defaultSelectionTitle: String?
    let emptyMessage: String?
}

private enum LibrariesSectionKind: Hashable {
    case library(LibrariesShelfStyle)
    case manage
}

private struct LibrariesItem: Hashable {
    let id: String
    let title: String
    let artworkURL: URL?
    let progress: Double?
    let isWatched: Bool
    let mediaItem: MediaItem?
    let route: AppRoute?
    let style: LibrariesShelfStyle
    let kind: LibrariesItemKind
    let iconName: String?
}

private enum LibrariesItemKind: Hashable {
    case openLibrary
    case media
    case manageServer
    case refresh(isRefreshing: Bool)
}

private struct LibrariesSectionReloadKey: Equatable {
    let id: String
    let kind: LibrariesSectionKind
    let itemKeys: [LibrariesItemReloadKey]
}

private struct LibrariesItemReloadKey: Equatable {
    let id: String
    let artworkURL: URL?
    let route: AppRoute?
    let style: LibrariesShelfStyle
    let kind: LibrariesItemKind
    let iconName: String?
}

private final class LibraryTileCell: UICollectionViewCell {
    static let reuseIdentifier = "LibraryTileCell"
    private static let placeholderImage = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
        AppTheme.uiSurfaceFill.setFill()
        context.fill(CGRect(origin: .zero, size: CGSize(width: 8, height: 8)))
    }

    private let imageView = UIImageView()
    private let progressView = ArtworkProgressIndicatorView()
    private let placeholderStack = UIStackView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private var imageTask: Task<Void, Never>?
    private var currentArtworkURL: URL?
    private var isShowingArtwork = false

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

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = AppTheme.uiSecondaryText
        titleLabel.numberOfLines = 2
        titleLabel.textAlignment = .center

        placeholderStack.axis = .vertical
        placeholderStack.alignment = .center
        placeholderStack.spacing = 16
        placeholderStack.translatesAutoresizingMaskIntoConstraints = false

        placeholderStack.addArrangedSubview(iconView)
        placeholderStack.addArrangedSubview(titleLabel)
        PlatformMetadata.overlayContent(for: imageView).addSubview(placeholderStack)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        PlatformMetadata.overlayContent(for: imageView).addSubview(progressView)

        contentView.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            placeholderStack.leadingAnchor.constraint(greaterThanOrEqualTo: PlatformMetadata.overlayContent(for: imageView).leadingAnchor, constant: 24),
            placeholderStack.trailingAnchor.constraint(lessThanOrEqualTo: PlatformMetadata.overlayContent(for: imageView).trailingAnchor, constant: -24),
            placeholderStack.centerXAnchor.constraint(equalTo: PlatformMetadata.overlayContent(for: imageView).centerXAnchor),
            placeholderStack.centerYAnchor.constraint(equalTo: PlatformMetadata.overlayContent(for: imageView).centerYAnchor),

            progressView.trailingAnchor.constraint(equalTo: PlatformMetadata.overlayContent(for: imageView).trailingAnchor, constant: -WatchProgressCircle.padding),
            progressView.bottomAnchor.constraint(equalTo: PlatformMetadata.overlayContent(for: imageView).bottomAnchor, constant: -WatchProgressCircle.padding),
            progressView.widthAnchor.constraint(equalToConstant: WatchProgressCircle.size),
            progressView.heightAnchor.constraint(equalToConstant: WatchProgressCircle.size)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(item: LibrariesItem) {
        let artworkURL = item.artworkURL
        let didChangeArtwork = currentArtworkURL != artworkURL

        accessibilityLabel = item.title
        currentArtworkURL = artworkURL
        titleLabel.text = item.title
        iconView.image = UIImage(systemName: item.iconName ?? item.style.placeholderIconName)
        progressView.setProgress(item.progress, isWatched: item.isWatched)

        if didChangeArtwork {
            imageTask?.cancel()
            imageTask = nil
            isShowingArtwork = false
            imageView.image = Self.placeholderImage
            placeholderStack.isHidden = false
        }

        guard let artworkURL else {
            imageView.image = Self.placeholderImage
            placeholderStack.isHidden = false
            isShowingArtwork = false
            return
        }

        guard !isShowingArtwork else { return }
        guard imageTask == nil else { return }

        if let image = ArtworkImageCache.shared.image(for: artworkURL) {
            imageView.image = image
            placeholderStack.isHidden = true
            isShowingArtwork = true
            return
        }

        imageTask = Task { [weak self] in
            let image = await ArtworkImageCache.shared.loadImage(from: artworkURL)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self, self.currentArtworkURL == artworkURL else { return }
                self.imageTask = nil
                guard let image else { return }
                self.imageView.image = image
                self.placeholderStack.isHidden = true
                self.isShowingArtwork = true
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
        imageTask = nil
        currentArtworkURL = nil
        isShowingArtwork = false
        imageView.image = Self.placeholderImage
        placeholderStack.isHidden = false
        progressView.setProgress(nil, isWatched: false)
    }
}

private final class LibrariesActionCell: UICollectionViewListCell {
    static let reuseIdentifier = "LibrariesActionCell"
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let titleLabel = UILabel()
    private let stackView = UIStackView()
    private var isRefreshing = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
        contentView.clipsToBounds = false

        activityIndicator.hidesWhenStopped = true

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.numberOfLines = 1
        titleLabel.textAlignment = .center

        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(activityIndicator)
        stackView.addArrangedSubview(titleLabel)

        contentView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 28),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -28),
            stackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, isRefreshing: Bool) {
        titleLabel.text = title
        self.isRefreshing = isRefreshing
        if isRefreshing {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
        setNeedsUpdateConfiguration()
    }

    override func updateConfiguration(using state: UICellConfigurationState) {
        super.updateConfiguration(using: state)

        let isFocused = state.isFocused && !isRefreshing
        let foregroundColor = isFocused
            ? AppTheme.uiInverseText
            : isRefreshing ? AppTheme.uiSecondaryText : AppTheme.uiPrimaryText
        titleLabel.textColor = foregroundColor
        activityIndicator.color = foregroundColor

        var background = UIBackgroundConfiguration.clear().updated(for: state)
        background.cornerRadius = 36
        background.backgroundColor = isFocused ? AppTheme.uiPrimaryText : AppTheme.uiSurfaceBorder
        background.strokeColor = isFocused ? .clear : AppTheme.uiPrimaryText.withAlphaComponent(isRefreshing ? 0.14 : 0.28)
        background.strokeWidth = isFocused ? 0 : 1
        backgroundConfiguration = background
    }
}

private final class LibrariesSectionFooterView: UICollectionReusableView {
    static let reuseIdentifier = "LibrariesSectionFooterView"
    private let verticalInset: CGFloat = 12

    private let label = UILabel()

    var title: String? {
        didSet {
            label.text = title
            setNeedsLayout()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = AppTheme.uiSecondaryText
        label.numberOfLines = 1
        label.lineBreakMode = .byClipping
        label.setContentCompressionResistancePriority(.required, for: .horizontal)

        addSubview(label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let availableHeight = max(bounds.height - verticalInset, 0)
        let labelSize = label.sizeThatFits(
            CGSize(width: .greatestFiniteMagnitude, height: availableHeight)
        )
        label.frame = CGRect(
            x: 0,
            y: verticalInset,
            width: labelSize.width,
            height: min(labelSize.height, availableHeight)
        )
    }
}

private final class LibrariesServerHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "LibrariesServerHeaderView"
    private let horizontalInset: CGFloat = 48
    private let label = UILabel()

    var title: String? {
        didSet { label.text = title }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        label.font = .preferredFont(forTextStyle: .title1).withTraits(.traitBold)
        label.textColor = AppTheme.uiPrimaryText
        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalInset),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -horizontalInset),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 44),
            label.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -40)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class LibrariesSectionHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "LibrariesSectionHeaderView"
    private let verticalInset: CGFloat = 12

    private let label = UILabel()

    var title: String? {
        didSet { label.text = title }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        label.font = .preferredFont(forTextStyle: .title3).withTraits(.traitBold)
        label.textColor = AppTheme.uiPrimaryText
        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -verticalInset)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private enum LibrariesShelfStyle: Hashable {
    case poster
    case wide

    var aspectRatio: CGFloat {
        switch self {
        case .poster:
            return 2 / 3
        case .wide:
            return 16 / 9
        }
    }

    var columns: CGFloat {
        switch self {
        case .poster:
            return 6
        case .wide:
            return 4
        }
    }

    var mediaArtworkStyle: MediaArtworkStyle {
        switch self {
        case .poster:
            return .poster
        case .wide:
            return .landscape
        }
    }

    func cellSize(for availableWidth: CGFloat) -> CGSize {
        let spacing: CGFloat = 44
        let width = floor((availableWidth - (spacing * (columns - 1))) / columns)
        let height = floor(width / aspectRatio)
        return CGSize(width: width, height: height)
    }

    var placeholderIconName: String {
        switch self {
        case .poster:
            return "film.stack.fill"
        case .wide:
            return "tv.fill"
        }
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
