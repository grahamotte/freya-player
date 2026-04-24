# Freya Player Agent Guide

## Product Goal

- Build a native Apple tvOS and iPad player for Plex and Jellyfin.
- Keep the app focused, fast, and intentionally small.
- Make everything feel stock Apple: platform-standard UI, APIs, behaviors, and code.

## Engineering Rules

- Write the least code that solves the problem well.
- Prefer Apple frameworks over dependencies.
- Prefer SwiftUI, AVKit, URLSession, and system navigation/presentation patterns.
- Avoid custom player chrome unless the native player cannot do the job.
- Keep UI very standard for each platform: prefer stock SwiftUI, tvOS focus behavior, and iPad navigation/presentation patterns over custom chrome.
- Keep the folder structure shallow and obvious.
- Build and run through `mise` and `xcodebuild`, not through Xcode UI steps.
- You may use the credentials in creds.txt to query a real plex or jellyfin instance if needed.

## Repo Conventions

- `mise start` should be the fastest loop: rebuild, then install and launch the tvOS app in an Apple TV simulator and the iPad app in an iPad simulator.
- `mise build` should produce a simulator build.
- After finishing a change, run `mise start` so a fresh build is running for verification.
- Documentation should stay short and practical.

## Feature Layout

- Keep the app shell in the root files: `FreyaPlayerApp.swift`, `AppView.swift`, `AppModel.swift`, `AppRoute.swift`.
- Put truly shared UI in `FreyaPlayer/Components/`.
- Put truly shared non-view helpers in `FreyaPlayer/Libraries/`.
- Put app-owned shared models in `FreyaPlayer/Models/`.
- Put all user-facing screens in `FreyaPlayer/Pages/<Feature>/`.
- Inside each page feature, use `Components/` for shared feature UI and `TvOS/` plus `IpadOS/` for thin platform wrappers.
- Put provider-specific integration code in `FreyaPlayer/Connectors/<Provider>/`.
- Keep feature-specific helpers next to the page or component that uses them; only promote code into `Components/` or `Libraries/` after a real second use.
- Prefer shallow folders like `Pages/Library/TvOS` or `Pages/Setup/Components`, not deep architectural nesting.
- Keep filenames PascalCase. If Xcode would collide on duplicate Swift basenames across platforms, use platform-prefixed wrapper filenames like `TvOSMovieItemPage.swift` and `IpadOSMovieItemPage.swift` while keeping the type names clean.

## Folder Overview

- `FreyaPlayerApp.swift`, `AppView.swift`, `AppModel.swift`, `AppRoute.swift`: app shell, global state, and top-level navigation.
- `FreyaPlayer/Components/`: reusable UI building blocks shared across features.
- `FreyaPlayer/Libraries/`: shared non-view helpers like polling, persistence helpers, and platform metadata.
- `FreyaPlayer/Models/`: app-owned shared model definitions consumed by the UI and connectors.
- `FreyaPlayer/Pages/`: all setup, settings, library, and item screens.
- `FreyaPlayer/Pages/<Feature>/Components/`: shared components for that page family.
- `FreyaPlayer/Pages/<Feature>/TvOS/`: tvOS page wrappers and tvOS-only page implementations.
- `FreyaPlayer/Pages/<Feature>/IpadOS/`: iPad page wrappers and iPad-only page implementations.
- `FreyaPlayer/Connectors/MediaConnector.swift`: shared connector contract for loading, playback, and session actions.
- `FreyaPlayer/Connectors/Plex/`: all Plex-specific networking, models, decoding, auth/session storage, and connector mapping.
- `FreyaPlayer/Connectors/Jellyfin/`: Jellyfin-specific networking, models, decoding, auth/session storage, and connector mapping.

## Connector Rules

- Treat connectors as the provider boundary: Plex and Jellyfin API details should stop inside `FreyaPlayer/Connectors/<Provider>/`.
- Keep the UI and app shell working with app-owned types like `ConnectedServer`, `LibraryReference`, `LibraryShelf`, `MediaItem`, and `MediaPlaybackID`.
- Add new provider-specific models, decoding helpers, auth flows, and request code next to that provider's connector, not in `Libraries/`.
- Prefer mapping provider responses into app-owned models once at the connector boundary instead of leaking provider-specific fields upward.
- When adding Jellyfin support, make it satisfy the existing shared connector contract before changing browse UI types.
- If a helper is only used by one connector, keep it in that connector folder even if it feels "utility-like".
- Do not reintroduce old lowercase paths like `browsing/`, `management/`, `lib/`, `views/`, or `connectors/plex/`. Keep new code under the current PascalCase folders.

## References

- Plex API docs: `https://developer.plex.tv/pms/`
- Plex account linking should use the Plex PIN flow at `plex.tv/link`, then Plex resources/server APIs.
- Rivulet is a useful tvOS reference implementation for Plex auth and server discovery: `https://github.com/l984-451/Rivulet`

## Change Style

- Default to the simplest native implementation first.
- Add abstractions only after a real second use appears.
- If a choice trades cleverness for clarity, choose clarity.
- For navigation choices, prefer standard SwiftUI button styles before building custom surfaces.
- Keep important actions like `Cancel` in the normal vertical focus path; don't tuck them into layouts that are hard to reach with the Siri Remote.

## Platform Branching

- Avoid `#if os(tvOS)` (or `#if !os(tvOS)`) inside pages, view bodies, and feature code. It clutters layout code and hides intent.
- For runtime branching, use `PlatformMetadata.isTV` (or extend `PlatformMetadata` with whatever flag you need) so call sites stay plain Swift.
- For SwiftUI modifiers that genuinely don't exist on one platform (e.g. `textSelection`), wrap the `#if` in a single `View` extension under `Components/PlatformViewShims.swift` and call the shim from features.
- Whole-file gating with `#if os(tvOS)` at the top of a tvOS-only file (e.g. `Pages/Library/TvOS/...`) is fine; it's the inline branching inside shared view code we're avoiding.

## Platform Branching

- Avoid `#if os(tvOS)` (or `#if !os(tvOS)`) inside pages, view bodies, and feature code. It clutters layout code and hides intent.
- For runtime branching, use `PlatformMetadata.isTV` (or extend `PlatformMetadata` with whatever flag you need) so call sites stay plain Swift.
- For SwiftUI modifiers that genuinely don't exist on one platform (e.g. `textSelection`), wrap the `#if` in a single `View` extension under `Components/PlatformViewShims.swift` and call the shim from features.
- Whole-file gating with `#if os(tvOS)` at the top of a tvOS-only file (e.g. `Pages/Library/TvOS/...`) is fine; it's the inline branching inside shared view code we're avoiding.
