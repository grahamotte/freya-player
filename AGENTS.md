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
- Keep the folder structure shallow and obvious.
- Build and run through `mise` and `xcodebuild`, not through Xcode UI steps.

## Repo Conventions

- `mise start` should be the fastest loop: stop the running simulator app, rebuild, install, launch.
- `mise build` should produce a simulator build.
- `mise dist` should produce a release device build artifact without adding extra release machinery yet.
- Documentation should stay short and practical.

## Change Style

- Default to the simplest native implementation first.
- Add abstractions only after a real second use appears.
- If a choice trades cleverness for clarity, choose clarity.
