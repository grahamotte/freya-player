# TVAU - Temporary tvOS audio fallback may outlive the platform bug

## user value

As an Apple TV viewer, I want Freya to retain native audio on fixed tvOS releases, so that a workaround for an earlier platform bug does not unnecessarily reduce playback quality.

## Problem description

Freya currently forces transcoded audio on tvOS 27 prerelease builds identified by a lowercase build suffix. This protects playback through affected HomePod routes, but it overrides the device's detected AC-3 and E-AC-3 capabilities and forces AAC for every playback path on those builds.

The affected platform behavior and build-number convention are temporary. Once Apple fixes the underlying issue, the fallback can unnecessarily remain active or become an inaccurate proxy for the routes that need it.

The desired outcome is for Freya to stop forcing AAC when the platform no longer requires the compatibility fallback, without reintroducing broken audio on genuinely affected tvOS and HomePod combinations.

## Status, notes, context, etc

- Created as a follow-up to NATP, which intentionally preserves the existing safeguard while expanding capability-gated native audio playback.
- The current fallback is implemented by `PlaybackCompatibility.requiresTranscodedAudio`.

## Prompts

> The tvOS prerelease/HomePod workaround still forces AAC when necessary.

lets add a card to remove this in the future

Created a future problem card for retiring the temporary tvOS/HomePod AAC fallback once the underlying platform behavior is fixed.
