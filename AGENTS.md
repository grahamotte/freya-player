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
- `scripts/` - General-purpose scripts.
- `mise.toml` - Project tooling and task definitions.

## Repo Specific

### Overall Rules

When the user says "remember this" or similar, do this:

- Review the current chat conversation in its entirety.
- Review the introspection document located at <project_root>/.cursor/rules/introspection.mdc
- Update this file with any significant learnings from the conversation.
- Remember, this file is for general structural notes about the system, getting too specific will muddle the usefulness of the document.
- Also, remember, these notes are for you in the future, so orient them as such.

### Ruby

- Do not add comments to the code
- Run specific test with `mise exec -- bundle exec ruby -I test <file>`
- Do not use .empty?, .nil?, if obj, etc - use .blank? or .present? always
- NEVER use `sleep`, you are doing something wrong if you sleep
- Always test your code unless explicitly told not to
- Always use double quotes for strings
- Always add a trailing comma in multiline lists of arguments

### Typescript

- Whenever something is null it's null | undefined, in zod terms it's nullish, NEVER type or check just null or just undefined, always both.
- Do not add comments to the code
- Test TypeScript business logic with its corresponding unit test file
- Use `pnpm`, not npm
- Use `mise tsc` to typecheck -- DO NOT TYPE CHECK ANY OTHER WAY!
- Use lodash when possible
- Use ShadCN components, ask for them to be installed if they dont exist
- Use tailwind for styles

### Freya Player

#### Aim

Freya is a small native Apple video player for Plex and Jellyfin on tvOS, iOS, and Mac Catalyst. Prefer stock Apple UI, platform behavior, SwiftUI, AVKit, URLSession, and the least code that solves the problem well. The Apple app lives in `apps/apple/App`; its project is `apps/apple/App.xcodeproj`.

#### Core Model

- **Connector**: Plex or Jellyfin. Provider API details stay under `apps/apple/App/Connectors/<Provider>/`.
- **ConnectedServer**: the active provider/server/account plus its library shelves.
- **LibraryReference**: stable identity and display defaults for a library.
- **LibraryShelf**: a library as shown on the home page, including preview items and hidden state.
- **MediaItem**: app-owned movie, series, season, episode, or other item. UI should use this, not provider models.
- **MediaPlaybackID**: provider/item identity for playback and watched-state writes.
- **LibraryCache**: in-memory plus JSON cache. This is the UI source of truth for library contents.
- **RefreshTracker**: dedups and exposes in-flight background refresh work.
- **MediaSessionStore**: `UserDefaults` for library filters, sort defaults, library order, and hidden libraries.

#### Architecture

- `AppView` owns the navigation stack and routes with `AppRoute`.
- `AppModel` owns connection lifecycle, active connector choice, cache mutation, refresh scheduling, library ordering/hiding, and playback reporting.
- Views read from `LibraryCache` and `AppModel`; they should not await network work except user-initiated playback URL/options.
- Connectors fetch provider data, map it into app-owned models, and feed `LibraryCache` through `AppModel`.
- Connector HTTP uses `GatedURLSession` and `RequestScheduler`; do not add unbounded connector `URLSession` calls.
- Refreshes are fire-and-forget from views. Cache changes and `RefreshTracker` updates repaint the UI.
- Mutations are optimistic: update the cache first, sync second, and revert on failure.
- User-visible watched state for collections is derived from cached leaves the app actually shows, not provider rollups.
- Polling is for slow cache repaint/connection refresh cadence; network refreshes also happen on appearance and user action.

#### Playback

- `MediaPlayButton` resolves playback options/URLs and presents `StockPlayerView`.
- `MediaPlayerLifecycle` handles resume seek, timeline reporting, completion, and stall recovery.
- `MediaPlayerItemFactory` attaches metadata/artwork to `AVPlayerItem`.
- Plex and Jellyfin playback quirks belong in their connector/client files.
- Playback completion should keep local watched state in sync immediately; do not rely only on a later refresh.

#### Layout

- App shell: `FreyaPlayerApp.swift`, `AppView.swift`, `AppModel.swift`, and `AppRoute.swift`.
- Shared UI: `apps/apple/App/Components/`.
- Shared non-view helpers: `apps/apple/App/Libraries/`.
- App-owned data types: `apps/apple/App/Models/`.
- Connector contract: `apps/apple/App/Connectors/MediaConnector.swift`.
- Provider implementations: `apps/apple/App/Connectors/Plex/` and `apps/apple/App/Connectors/Jellyfin/`.
- User-facing screens: `apps/apple/App/Pages/<Feature>/`.
- Page-specific shared UI: `apps/apple/App/Pages/<Feature>/Components/`.
- Keep helpers beside the feature that uses them until there is a real second use.
- Keep folders shallow and filenames PascalCase.

#### Pages

- **Setup**: provider picker plus Plex PIN flow and Jellyfin username/password flow.
- **Libraries page**: home page for the connected server. It uses `LibrariesHomeProjection` over `ConnectedServer` and `LibraryCache`.
- **Library page**: browses one library with filter/sort controls managed by `LibraryPageState`.
- **Item page**: detail pages for movies, series, seasons, episodes, and other media.
- **Settings page**: server management, cache clearing/resync, default library controls, library ordering, and hidden libraries.
- **About page**: app info.

#### Platforms

- Keep compile-time platform checks in `apps/apple/App/Libraries/PlatformMetadata.swift` where possible.
- Use `PlatformMetadata` and `PlatformLibraryPageContent` / `PlatformLibrariesPageContent` for platform selection.
- tvOS has custom UIKit collection views for focused library browsing. Keep tvOS actions, especially `Cancel`, in the normal vertical focus path.
- iOS and Mac Catalyst mostly use SwiftUI layouts.

#### Connectors

- Keep Plex and Jellyfin API details, decoding, auth storage, playback URL construction, and provider errors inside provider folders.
- Map provider models into `ConnectedServer`, `LibraryReference`, `LibraryShelf`, `MediaItem`, and `MediaPlaybackID` at the connector boundary.
- Provider-only helpers stay with that provider, even if they look utility-like.
- Do not reintroduce old lowercase paths like `browsing/`, `management/`, `lib/`, `views/`, or `connectors/plex/`.

#### Workflow

- Build, test, simulate, and publish through the root `mise` tasks and Code Moto tooling, not copied legacy scripts or Xcode UI steps.
- `mise test` runs the complete repository suite, including the portable Apple core tests.
- `mise simulate` builds, installs, and launches configured Apple simulator targets.
- `mise xcode` opens the Apple Xcode project.
- Use `$publish` for the configured Apple release workflow.
- You may use `creds.txt` to query real Plex or Jellyfin instances when needed.
- Keep documentation short and practical.

#### References

- Plex API docs: `https://developer.plex.tv/pms/`
- Plex account linking uses the PIN flow at `plex.tv/link`.
- Rivulet can be a useful tvOS Plex reference: `https://github.com/l984-451/Rivulet`
