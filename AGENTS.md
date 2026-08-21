# AGENTS.md

## Code Moto

This repo is based on Code Moto. Code Moto is a basis/template repository that provides tools and patterns for downstream repositories. From a downstream repository, the basis repository is typically available at `../codemoto.org`. If the current repository is named `codemoto.org`, changes affect the Code Moto framework itself.

Repositories based on Code Moto may omit components or add their own. Backport broadly useful tools and changes to `codemoto.org` when practical.

The "Repo Specific" section blow contains rules specific to this repo only.

## Project Rules

1. Do not introduce bugs or regressions.
2. Before writing code, find analogous code in the repository and follow its established patterns.
3. Do not add comments to code. Preserve existing comments unless they are incorrect or obsolete.
4. Lint, type-check, and test code changes using the tasks defined in the root `mise.toml`.
5. Use root `mise` tasks instead of invoking underlying tools directly when an applicable task exists.
6. Do not create a canvas or visualization unless the user specifically requests one.

## Ruby

- Use `.blank?` and `.present?` for presence checks instead of `.empty?`, `.nil?`, or truthiness checks.
- Do not use `sleep`; use an event- or state-based approach instead.
- Add trailing commas to multiline argument lists and collections.

## TypeScript

- Treat nullable values as both `null` and `undefined`; use `nullish()` in Zod schemas and check for both states.
- Use `pnpm`, not `npm`.
- Use `mise tsc` to type-check.
- Prefer Lodash utilities over custom equivalents when Lodash is already available.
- Use shadcn/ui components.
- Use Tailwind CSS for styling.

## Testing

- Never run network requests, system commands, or application sleeps in tests. Stub those boundaries every time.
- Do not stub other units in a unit test. Only stub network requests, system commands, and sleeps so the real local collaborators and full local surface are exercised together.
- Every business-logic file must have one corresponding unit test file. Source and test files are 1:1.
- Test each business-logic unit thoroughly. Configuration, generated files, framework shells, and other files without business logic do not need tests.
- After every code change, run the whole suite with `mise test`.
- Do not write integration tests.

## Kanban

- `kanban/` is the repository's local work board. When using it, read and follow `kanban/README.md`.
- Only use the Kanban board when the user asks to create or manage cards, or asks for work on an existing card. Other work does not require a card.
- Never create a card unless the user explicitly instructs you to do so.
- When the user requests standalone card management, commit only the requested card changes immediately without asking for confirmation.

## File Structure

- `.agents/skills/` - Project-specific agent skills.
- `.env.*` - Environment configuration and secrets. Do not expose secret values.
- `apps/` - Mobile apps for iOS and Android.
- `apps/config.json` - Mobile app release configuration.
- `assets/` - Shared images and media.
- `backend/` - Ruby on Rails API server.
- `deploy/` - Backend, frontend, and mobile app deployment tooling.
- `docs/` - Project documentation in Markdown.
- `frontend/` - React website.
- `frontend/subdomains.json` - Website subdomain configuration.
- `gems/` - Shared Ruby gems.
- `kanban/` - Repository-local work board and workflow instructions.
- `scripts/` - General-purpose scripts.
- `mise.toml` - Project tooling and task definitions.

## Repo Specific

### Freya Player

Freya Player is a native Apple client for personal Plex and Jellyfin servers. The stated goal of Freya Player is to play everything Apple supports natively, exceptionally well. Use server conversion only for what Apple genuinely cannot play.

It targets tvOS, iOS and iPadOS, and Mac Catalyst. Prefer stock platform behavior, SwiftUI, AVKit, Foundation networking, and the least code that solves the problem well. Use UIKit where tvOS focus or collection-view behavior requires it.

### Apple App Architecture

- The Apple app source is in `apps/apple/App`; the Xcode project is `apps/apple/App.xcodeproj`.
- `AppView` owns navigation through `AppRoute`. `AppModel` owns connection state, connector selection, refresh scheduling, cache mutation, library preferences, and playback reporting.
- UI code consumes app-owned models such as `ConnectedServer`, `LibraryShelf`, `LibraryReference`, `MediaItem`, and `MediaPlaybackID`. Do not expose Plex or Jellyfin response models outside their provider implementation.
- Keep provider API details, decoding, authentication storage, playback URL construction, and provider errors under `apps/apple/App/Connectors/Plex` or `apps/apple/App/Connectors/Jellyfin`. Shared connector behavior belongs in `MediaConnector` only when both providers need it.
- `LibraryCache` is the UI source of truth for loaded media. Views schedule refreshes through `AppModel`; cache and `RefreshTracker` changes drive repainting.
- Keep refresh work deduplicated through `RefreshTracker`, and route connector HTTP through `URLSession.gatedData` and `RequestScheduler`.
- Apply watched-state mutations optimistically, sync them through the connector, and restore the previous cached state on failure. Playback completion must update local watched state immediately.
- `PlaybackSessionController` owns AVPlayer lifecycle, timeline reporting, and recovery. `MediaPlayerItemFactory` owns `AVPlayerItem` metadata and artwork. Provider-specific playback behavior stays in provider clients and connectors.

### Apple App Layout

- Shared views and playback UI: `apps/apple/App/Components/`.
- Shared non-view infrastructure: `apps/apple/App/Libraries/`.
- App-owned data types: `apps/apple/App/Models/`.
- User-facing features: `apps/apple/App/Pages/<Feature>/`, with feature-only components under that page.
- Keep a helper with its feature until it has a real second use. Keep folders shallow and Swift filenames PascalCase.
- Centralize platform differences in `PlatformMetadata`, `PlatformLibraryPageContent`, and `PlatformLibrariesPageContent` where practical. Preserve normal tvOS focus movement when adding actions to UIKit collection views.

### Apple Workflow

- Use the root `mise` tasks for Apple work.
- `mise test` runs the repository suite, including the portable Apple logic tests. It does not compile every platform-specific Swift file. Do not run `mise simulate` unless the user explicitly requests it; the user will normally perform simulator validation.
- Use `mise xcode` to open the project and `$publish` for the release workflow.
- Keep documentation short and practical.
