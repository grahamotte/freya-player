# Freya Player Agent Guide

## Product Goal

- Build a native Apple tvOS player for Plex and Jellyfin.
- Keep the app focused, fast, and intentionally small.
- Make everything feel stock Apple: platform-standard UI, APIs, behaviors, and code.

## Engineering Rules

- Write the least code that solves the problem well.
- Prefer Apple frameworks over dependencies.
- Prefer SwiftUI, AVKit, URLSession, and system navigation/presentation patterns.
- Avoid custom player chrome unless the native player cannot do the job.
- Keep UI very standard tvOS: prefer stock SwiftUI/tvOS controls and focus behavior over custom card treatments.
- Keep the folder structure shallow and obvious.
- Build and run through `mise` and `xcodebuild`, not through Xcode UI steps.
- You may use the credentials in creds.txt to query a real plex or jellyfin instance if needed.

## Repo Conventions

- `mise start` should be the fastest loop: stop the running simulator app, rebuild, install, launch.
- `mise build` should produce a simulator build.
- After finishing a change, run `mise start` so a fresh build is running for verification.
- Documentation should stay short and practical.

## Feature Layout

- Keep the app shell in the root files: `FreyaPlayerApp.swift`, `AppView.swift`, `AppModel.swift`, `AppRoute.swift`.
- Put server setup and manage flows in `FreyaPlayer/management/`.
- Put connected-server browsing flows in `FreyaPlayer/browsing/`.
- Put provider-specific integration code in `FreyaPlayer/connectors/<provider>/`.
- Put provider-agnostic connector contracts and app-owned media models in `FreyaPlayer/connectors/`.
- Put only truly shared non-provider helpers in `FreyaPlayer/lib/`.
- Put only truly shared UI pieces in `FreyaPlayer/views/`.
- Keep feature-specific helpers next to the view that uses them; only promote code into `lib` or `views` after a real second use.
- Prefer shallow folders like `management/plex-setup` or `browsing/tv-library`, not deep architectural nesting.

## Folder Overview

- `FreyaPlayerApp.swift`, `AppView.swift`, `AppModel.swift`, `AppRoute.swift`: app shell, global state, and top-level navigation.
- `FreyaPlayer/management/`: provider picking, setup, and manage-server flows.
- `FreyaPlayer/browsing/`: connected browsing UI such as libraries, library pages, and item detail screens.
- `FreyaPlayer/connectors/MediaConnector.swift`: shared connector contract for loading, playback, and session actions.
- `FreyaPlayer/connectors/MediaModels.swift`: app-owned browse and playback models that the UI should consume.
- `FreyaPlayer/connectors/plex/`: all Plex-specific networking, models, decoding, auth/session storage, and connector mapping.
- `FreyaPlayer/connectors/jellyfin/`: Jellyfin-specific connector code as it is added.
- `FreyaPlayer/lib/`: shared helpers that are not tied to one provider, like polling or shared persistence helpers.
- `FreyaPlayer/views/`: reusable UI building blocks shared across features.

## Connector Rules

- Treat connectors as the provider boundary: Plex and Jellyfin API details should stop inside `FreyaPlayer/connectors/<provider>/`.
- Keep the UI and app shell working with app-owned types like `ConnectedServer`, `LibraryReference`, `LibraryShelf`, `MediaItem`, and `MediaPlaybackID`.
- Add new provider-specific models, decoding helpers, auth flows, and request code next to that provider's connector, not in `lib/`.
- Prefer mapping provider responses into app-owned models once at the connector boundary instead of leaking provider-specific fields upward.
- When adding Jellyfin support, make it satisfy the existing shared connector contract before changing browse UI types.
- If a helper is only used by one connector, keep it in that connector folder even if it feels "utility-like".
- `FreyaPlayer/lib/plex/` is old structure; do not add new code there. Keep new Plex work under `FreyaPlayer/connectors/plex/`.

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
