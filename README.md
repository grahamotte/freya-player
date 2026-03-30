# freya-player

Freya Player is a native tvOS app for watching video from Plex or Jellyfin with as much stock Apple feel as possible.

## Commands

- `mise build` builds the tvOS simulator app and publishes `./FreyaPlayer.app`
- `mise start` rebuilds, installs into the Apple TV simulator, and launches the app
- `mise dist` builds an unsigned Release app for real tvOS devices and publishes it in `./dist`

## Notes

- The app is intentionally just a minimal tvOS shell right now.
- The project is driven by `xcodebuild` and small shell scripts so it works well from VS Code and chat-driven workflows.
