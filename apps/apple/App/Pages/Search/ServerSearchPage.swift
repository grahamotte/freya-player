import Fuse
import SwiftUI
import UIKit

struct ServerSearchPage: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var search: ServerTitleSearch
    @FocusState private var isSearchFieldFocused: Bool

    init(model: AppModel, server: ConnectedServer) {
        _search = StateObject(
            wrappedValue: ServerTitleSearch(cache: model.libraryCache, server: server)
        )
    }

    var body: some View {
        Group {
            if PlatformMetadata.isTV {
                pageContent
                    .searchable(text: $search.query, prompt: "Search titles")
            } else {
                VStack(spacing: 0) {
                    searchHeader
                    pageContent
                }
                .toolbar(.hidden, for: .navigationBar)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            LibrariesAmbientBackground()
                .ignoresSafeArea()
        }
        .navigationTitle("")
        .navigationBarBackButtonHidden(!PlatformMetadata.isTV)
        .task {
            guard !PlatformMetadata.isTV else { return }
            isSearchFieldFocused = true
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        if search.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ContentUnavailableView(
                "Search Titles",
                systemImage: "magnifyingglass",
                description: Text("Type or dictate a few characters from a title.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if search.results.isEmpty {
            ContentUnavailableView.search(text: search.query)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            searchResults
        }
    }

    private var searchResults: some View {
        ScrollView {
            LazyVStack(spacing: PlatformMetadata.isTV ? 24 : 16) {
                ForEach(search.results) { result in
                    NavigationLink(value: result.item.route) {
                        SearchResultRow(
                            item: result.item,
                            title: highlightedTitle(for: result)
                        )
                    }
                    .buttonStyle(SearchResultButtonStyle())
                }
            }
            .padding(.horizontal, contentHorizontalPadding)
            .padding(.top, PlatformMetadata.isTV ? 28 : 0)
            .padding(.bottom, contentHorizontalPadding)
        }
        .scrollIndicators(.hidden)
    }

    private var searchHeader: some View {
        HStack(spacing: 16) {
            Button {
                dismiss()
            } label: {
                Label("Back", systemImage: "chevron.left")
            }
            .buttonStyle(
                MediaGlassButtonStyle(horizontalPadding: PlatformMetadata.isPhone ? 16 : 24)
            )

            HStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)

                TextField("Search titles", text: $search.query)
                    .textFieldStyle(.plain)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isSearchFieldFocused)
                    .submitLabel(.search)

                if !search.query.isEmpty {
                    Button {
                        search.query = ""
                        isSearchFieldFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear Search")
                }
            }
            .font(.title2)
            .padding(.horizontal, resultInnerHorizontalPadding)
            .padding(.vertical, 18)
            .background(AppTheme.surfaceFill)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        isSearchFieldFocused ? AppTheme.primaryText.opacity(0.8) : AppTheme.surfaceBorder,
                        lineWidth: isSearchFieldFocused ? 2 : 1
                    )
            }
        }
        .padding(.horizontal, contentHorizontalPadding)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    private var contentHorizontalPadding: CGFloat {
        PlatformMetadata.isPhone ? 16 : 48
    }

    private var resultInnerHorizontalPadding: CGFloat {
        PlatformMetadata.isPhone ? 18 : 32
    }

    private func highlightedTitle(for result: ServerTitleSearch.Result) -> Text {
        let units = Array(result.item.title.utf16)
        var text = Text("")
        var cursor = 0

        for range in result.matchedRanges {
            let start = min(max(range.start, cursor), units.count)
            let end = min(max(range.end + 1, start), units.count)
            if start > cursor {
                let unmatched = Text(String(decoding: units[cursor..<start], as: UTF16.self))
                    .foregroundColor(AppTheme.secondaryText)
                text = Text("\(text)\(unmatched)")
            }
            if end > start {
                let matched = Text(String(decoding: units[start..<end], as: UTF16.self))
                    .fontWeight(.heavy)
                    .foregroundColor(AppTheme.primaryText)
                text = Text("\(text)\(matched)")
            }
            cursor = end
        }

        if cursor < units.count {
            let unmatched = Text(String(decoding: units[cursor..<units.count], as: UTF16.self))
                .foregroundColor(AppTheme.secondaryText)
            text = Text("\(text)\(unmatched)")
        }
        return text
    }
}

private struct SearchResultRow: View {
    let item: MediaItem
    let title: Text

    var body: some View {
        HStack(spacing: PlatformMetadata.isTV ? 32 : 24) {
            SearchResultArtwork(item: item)

            VStack(alignment: .leading, spacing: PlatformMetadata.isTV ? 12 : 8) {
                title
                    .font(PlatformMetadata.isTV ? .title2 : .title3)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let metadata {
                    Text(metadata)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                }

                if let synopsis {
                    Text(synopsis)
                        .font(PlatformMetadata.isTV ? .body : .subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(resultPadding)
        .contentShape(Rectangle())
    }

    private var metadata: String? {
        if let releasedAt = item.releasedAtFormatted {
            return releasedAt
        }
        return item.year.map(String.init)
    }

    private var synopsis: String? {
        let value = item.synopsis.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private var resultPadding: CGFloat {
        PlatformMetadata.isPhone ? 16 : 20
    }
}

private struct SearchResultArtwork: View {
    let item: MediaItem

    @State private var image: UIImage?

    private var style: MediaArtworkStyle {
        item.kind.artworkStyle
    }

    private var artworkURL: URL? {
        item.artwork.url(for: style)
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: imageSize.width, height: imageSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppTheme.surfaceFill)
                    .frame(width: imageSize.width, height: imageSize.height)
                    .overlay {
                        Image(systemName: style == .poster ? "film.stack.fill" : "tv.fill")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
            }
        }
        .frame(width: previewDimension, height: previewDimension)
        .task(id: artworkURL) {
            image = nil
            guard let artworkURL else { return }
            image = await ArtworkImageCache.shared.loadImage(from: artworkURL)
        }
    }

    private var previewDimension: CGFloat {
        if PlatformMetadata.isTV { return 240 }
        if PlatformMetadata.isPhone { return 140 }
        return 200
    }

    private var imageSize: CGSize {
        if style.aspectRatio >= 1 {
            return CGSize(
                width: previewDimension,
                height: previewDimension / style.aspectRatio
            )
        }
        return CGSize(
            width: previewDimension * style.aspectRatio,
            height: previewDimension
        )
    }

    private var cornerRadius: CGFloat {
        PlatformMetadata.isPhone ? 12 : 16
    }
}

private struct SearchResultButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(AppTheme.primaryText)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isFocused ? AppTheme.emphasizedSurfaceFill : AppTheme.surfaceFill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        isFocused ? AppTheme.primaryText : AppTheme.surfaceBorder,
                        lineWidth: isFocused ? 3 : 1
                    )
            }
            .scaleEffect(configuration.isPressed ? 0.99 : isFocused ? 1.015 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.16), value: isFocused)
    }
}
