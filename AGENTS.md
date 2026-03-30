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

## Repo Conventions

- `mise start` should be the fastest loop: stop the running simulator app, rebuild, install, launch.
- `mise build` should produce a simulator build.
- `mise dist` should produce a release device build artifact without adding extra release machinery yet.
- After finishing a change, run `mise start` so a fresh build is running for verification.
- Documentation should stay short and practical.

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
