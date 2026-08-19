# Media cannot be downloaded for offline playback

## user value

As a Freya Player user, I want to download selected media at a suitable quality and manage those downloads, so that I can browse and play it when my Plex or Jellyfin server is unavailable without unexpectedly losing it.

## Problem description

Freya can browse cached library metadata while offline, but every play path currently resolves a fresh server URL and is disabled when `AppModel.isOffline` is true. There is no way to prepare media on the server, transfer it to the device, see its progress or storage use, play the local copy, retry an interrupted transfer, or remove it later.

The desired experience includes:

- A download action for playable items, with a quality/resolution choice and the relevant audio/subtitle choices where available.
- Server-side transcoding or remuxing when the selected quality or device compatibility requires it, followed by local playback that does not contact the server.
- Clear queued, preparing, downloading, failed, completed, missing/evicted, cancel, retry, and delete states.
- A management view that shows every active and completed download, its quality, progress, size, and storage total, with individual and bulk removal.
- A Downloaded library filter that reuses the normal library presentation. For a show or season, the result must be useful when only some descendant episodes are downloaded; offline quick play, shuffle, and child lists must never silently select a non-downloaded leaf.
- A convenient way to reach downloaded media from the top-level libraries page, not only from an individual library.
- Download and delete/cancel actions in item pages and quick actions, with unambiguous behavior for a movie, episode, season, or series.

This is one Apple app shared by iPhone, iPad, Apple TV, and Mac Catalyst. `apps/config.json` has no Android target, and the Rails/frontend projects are not media-player apps. The feature needs honest platform behavior rather than promising the same durability where the operating system cannot provide it.

## Investigation notes and current evidence

### Existing app behavior and reuse points

- `MediaConnector` already separates provider behavior and exposes playback options plus playback resource resolution. Both provider implementations already describe source height, lower quality choices (1080p/720p/480p/240p), audio tracks, subtitle tracks, and expected transcoding.
- `MediaPlaybackQuality` already maps those choices to Plex maximum video bitrate/resolution and Jellyfin maximum streaming bitrate/height. Streaming preferences are saved per item, but download defaults/preferences do not yet exist and should not accidentally overwrite playback preferences.
- `MediaPlayerItemFactory` already accepts a URL-backed `MediaPlaybackResource`, so a valid local file URL is compatible with the stock player path. The surrounding playback code assumes a server session, recovery URL, and immediate timeline reporting, so local playback still needs distinct offline behavior.
- `LibraryCache` is the UI source of truth and already retains enough hierarchy to browse a cached server. It is a single-server snapshot and prunes unreachable items. Connecting to another server, clearing the cache, or disconnecting clears that snapshot; none of those events should silently orphan or erase downloads without an explicit product decision.
- `LibraryPageFilter`, `LibraryPageState`, and `LibrariesHomeProjection` already share filtering between an individual library and the top-level shelf previews. Download membership is not currently part of `MediaItem`, and `LibraryPageFilter.matches` is a pure item-only check, so downloaded filtering cannot simply be added without making completed local state available to both projections.
- Item quick actions exist in SwiftUI and in the custom tvOS long-press handler. Both currently disable play while offline.
- `ArtworkImageCache` is memory-only. A cold launch without a server can browse cached text metadata but cannot reload artwork. A complete offline experience needs its downloaded titles and hierarchy to remain recognizable without relying on remote artwork URLs.
- Playback progress is applied optimistically to `LibraryCache`, but `PlaybackReportQueue` is in-memory and failed connector reports are discarded or reverted. Offline progress/completion must remain durable locally and reconcile with the correct server/user when connectivity returns.
- Network reachability is not server reachability. A device can have a satisfied network path while its personal server is unreachable. A completed local copy must remain playable in that condition as well as in airplane mode.

### Plex

Plex has a documented server-side Download Queue in the current Plex Media Server API. It can create a per-client/user queue, add item keys with video bitrate/resolution, audio, subtitle, direct-play/direct-stream, and `http`/`hls`/`dash` parameters, report decision and item status, return `503` while an item is still preparing, and return the finished raw media when available. It also exposes queue item deletion and restart operations. This closely matches the requested prepare-then-transfer lifecycle and is materially different from the existing streaming session endpoint.

Plex Downloads is a premium capability. Current Plex documentation says it requires the relevant Plex Pass entitlement, the server owner may need to grant “Allow Downloads,” and current mobile clients require Plex Media Server 1.41.2 or newer. The feature must expose unsupported server versions, entitlement/permission denial, transcoder failure, remote bandwidth limits, and non-personal content clearly instead of treating them as generic network errors. Capability and behavior need verification against both owned and shared servers; the API decision response includes download/sync eligibility information.

Freya currently uses Plex's HLS universal transcoder for non-direct playback. The regular transcoder endpoint can return HLS, DASH, or a binary HTTP stream, but it is a playback session and should not be assumed to have the persistence, retry, or cleanup semantics of the Download Queue.

### Jellyfin

Jellyfin's supported `GET /Items/{itemId}/Download` endpoint enforces the user's download permission and returns the original physical media file with range processing. It does not accept a target resolution, bitrate, codec, audio track, or subtitle selection.

Jellyfin's progressive `GET /Videos/{itemId}/stream[.{container}]` endpoint accepts video/audio codec, bitrate, size, audio stream, and subtitle parameters and transcodes when `Static` is false. In current Jellyfin server source, a transcoded progressive response explicitly advertises `Accept-Ranges: none`; the transcode is tied to the HTTP response rather than a durable preparation queue. An interruption may therefore require restarting both the transfer and server work. Jellyfin's HLS playback endpoint is another possible VOD source on platforms that can persist HLS, but Freya must not assume the server will retain streaming transcode artifacts after the session.

As of the current Jellyfin project discussion, a durable transcoded-download job endpoint is still only a proposal. Before treating quality-selected Jellyfin downloads as reliable, test real supported server versions for full-file completion, app suspension/termination, retry behavior, long transcodes, server cleanup, audio/subtitle selection, and direct local playback. Original-file downloads are substantially lower risk but may be too large or incompatible with the device.

### iPhone and iPad

iOS provides persistent app-container storage suitable for user-requested downloads and background HTTP downloads that continue while the app is suspended and can reconnect to the app after a system relaunch. A force-quit cancels background transfers, so interrupted work still needs a recoverable state on the next launch.

Large redownloadable media in Documents or Application Support must be excluded from device/iCloud backups. Application Support keeps app-private content out of the Files app; Caches is purgeable and is not appropriate for downloads presented as durable. Apple also provides `AVAssetDownloadURLSession` for offline HLS on iOS, but the downloaded asset remains at a system-managed URL and has different lifecycle rules from an ordinary file.

### Mac Catalyst

Mac Catalyst has persistent container storage and the macOS SDK exposes offline HLS asset downloads. Large media must likewise be excluded from backup. Background completion/relaunch behavior and cancellation need validation in the actual Catalyst target, especially because the current plist enables automatic and sudden termination. A normal app quit, forced termination, interrupted network, and relaunch must not corrupt the download index or leave unmanageable files.

### Apple TV

tvOS is the hard limitation. Apple documents only 500 KB of guaranteed local persistent storage via `UserDefaults`; all larger local data must be purgeable by the operating system. The existing `LibraryCacheStorage` already uses Caches on tvOS instead of Application Support for this reason. The Xcode 26.2 SDK marks `AVAssetDownloadTask`, `AVAssetDownloadURLSession`, and its delegate unavailable on tvOS, so the iOS/macOS offline-HLS facility cannot be the shared implementation. Standard background HTTP download sessions are available on tvOS, but their resulting media still has to live in purgeable cache storage.

Freya therefore cannot truthfully guarantee that a downloaded Apple TV file will survive storage pressure while the app is not running. The product behavior must explicitly choose between no tvOS download support and a best-effort “offline cache” that can be evicted. If best-effort caching is offered, the UI must explain the limitation, reconcile its index with actual files at every launch/resume, remove stale “downloaded” badges promptly, and never lose the rest of the library cache merely because one media file was purged. There is no appropriate local directory that turns multi-gigabyte tvOS downloads into durable user data.

## Data integrity and lifecycle outcomes

The feature is not complete if it only downloads a playable URL once. It must also account for:

- Stable identity across provider, server, user/account, library, and media item. IDs from different servers can collide.
- Enough local metadata, hierarchy, selected quality/audio/subtitle information, artwork, byte size, and completion state to browse and manage a title without contacting the server.
- An index that survives relaunch independently of temporary transfer state, records background completion safely, and never marks media complete until the final local asset is present and playable.
- Reconciliation after crashes, force-quits, OS eviction, partial writes, a missing file, an orphan file, an app upgrade, a server-side item deletion, token changes, server switching, cache clearing, and sign-out. Whether sign-out deletes downloads is a privacy/product decision that must be explicit and confirmed before implementation.
- Cancellation and deletion that stop client transfer work, clean partial and completed files, clean provider-side preparation jobs where supported, and update all filters/badges without leaving storage behind.
- Low-disk checks, useful size reporting, deterministic cleanup on failure, and clear errors when the selected quality cannot fit or cannot be produced.
- No long-lived storage of authenticated media URLs or access tokens in the download index. Existing provider credentials remain Keychain-owned.
- Local-first playback for completed downloads even when a network path exists. Seeking, resume, metadata, and artwork must not trigger server access.
- Durable local watched/progress changes from offline playback and ordered retry when the matching server/user becomes reachable. Deleting the media must not discard unsynced playback state.
- Isolation between active, failed, partially downloaded, completed, and tvOS-evicted items so that a library filter never claims unavailable content is playable offline.

## Scope and behavior questions to settle during implementation

- Does downloading a series or season enqueue all current episodes, only unwatched episodes, or present a choice? How are newly added episodes handled?
- Does “Downloaded” include in-progress items, or only locally playable completed items? Management should show both even if the library filter only shows completed items.
- When one episode is downloaded, should the normal series and season pages show only downloaded descendants while offline, or show all cached descendants with unavailable state?
- Are download quality defaults global, per provider, or per item, and is “Original” distinct from “Automatic”?
- Are selected subtitles embedded/burned, downloaded as sidecars, or omitted when the provider/container cannot preserve them? The displayed choice must match what actually works offline.
- Should completed downloads always win over server streaming, or only when offline/a Downloaded view is active? The request favors always direct-playing the local file, but this should be confirmed because Plex's own apps distinguish server-library playback from Downloads playback.
- What does Clear Cache do to tvOS offline media, and what do disconnect/sign-out and changing servers do on every platform?
- Is tvOS best-effort caching valuable enough despite unavoidable eviction, or should the download action be unavailable there with a clear explanation?

## Verification expectations

Exercise at least the following on physical devices where background behavior or storage eviction is involved:

- iPhone, iPad, Apple TV, and Mac Catalyst; cold launch, background, system termination, user force-quit/quit, relaunch, and app upgrade.
- Plex and Jellyfin; owned and shared/non-admin users; allowed and denied downloads; supported and older server versions; local and remote servers; HTTP and HTTPS.
- Movie and episode, plus partial series/season downloads; direct-play original, remux, video transcode, audio-only transcode, selected audio, no subtitle, text subtitle, and burn-required subtitle.
- Wi-Fi loss and recovery, app suspension mid-transfer, server restart mid-preparation and mid-transfer, expired credentials, insufficient local space, server transcode failure, cancellation, retry, deletion, and provider-side cleanup.
- File/index mismatch and tvOS cache eviction, including confirmation that stale downloaded state disappears without damaging cached library browsing.
- Playback with all networking disabled and playback when the internet is available but the personal server is down. Verify seek, resume, completion, artwork, quick play, shuffle, local watched state, and later server reconciliation.
- Storage totals and removal against the actual bytes on disk, including partial/orphan cleanup.

Business-logic additions require corresponding portable unit tests under `apps/apple/Tests`; platform transfer and storage behavior still needs focused validation in the real app because `mise test` does not compile every platform-specific Swift file.

## References

- [Apple: Using the file system effectively](https://developer.apple.com/documentation/foundation/using-the-file-system-effectively)
- [Apple: Downloading files in the background](https://developer.apple.com/documentation/foundation/downloading-files-in-the-background)
- [Apple: Offline playback and storage](https://developer.apple.com/documentation/avfoundation/offline-playback-and-storage)
- [Apple: tvOS local storage is limited](https://developer.apple.com/library/archive/documentation/General/Conceptual/AppleTV_PG/)
- [Plex Media Server API, including Download Queue and Transcoder](https://developer.plex.tv/pms/)
- [Plex Downloads FAQ](https://support.plex.tv/articles/downloads-sync-faq/)
- [Plex Downloads for iOS and Android](https://support.plex.tv/articles/download-ios-android/)
- [Jellyfin original-file download endpoint](https://github.com/jellyfin/jellyfin/blob/master/Jellyfin.Api/Controllers/LibraryController.cs)
- [Jellyfin progressive video endpoint](https://github.com/jellyfin/jellyfin/blob/master/Jellyfin.Api/Controllers/VideosController.cs)
- [Jellyfin progressive response and range behavior](https://github.com/jellyfin/jellyfin/blob/master/Jellyfin.Api/Helpers/FileStreamResponseHelpers.cs)
- [Jellyfin transcoded-download proposal](https://github.com/jellyfin/jellyfin-meta/discussions/115)
