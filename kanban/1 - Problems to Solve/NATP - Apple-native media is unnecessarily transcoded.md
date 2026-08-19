# Apple-native media is unnecessarily transcoded

## user value

As a viewer, I want Freya to preserve every media format my Apple device can play natively, so that I receive the original video and audio quality without unnecessary server work.

## Problem description

Freya's Plex and Jellyfin compatibility rules are more restrictive than the native media capabilities of current Apple devices. Compatible AC-3 and E-AC-3 audio can be converted to AAC, HEVC and HDR video can be converted to H.264 when only the container or audio is incompatible, and common playback choices can cause both tracks to be transcoded when a narrower conversion would be sufficient.

As a result, supported surround sound, Dolby Atmos, HDR10, HDR10+, HLG, Dolby Vision, resolution, and bitrate may be lost even though the playback device could preserve some or all of the original media. Behavior also varies by device, operating system, output route, provider, container, selected tracks, subtitles, and local or remote connection.

The desired outcome is for Freya to direct play or preserve each Apple-native media component whenever the current device and playback route support it, use server remuxing or track-specific conversion when only part of the media is incompatible, and convert video only when native presentation is genuinely unavailable.

## Status, notes, context, etc

- Freya's product goal is excellent native Apple playback rather than a custom general-purpose codec engine.
- Capability claims and provider negotiation must remain device-aware and must not promise support merely because a source label names a premium format.
- This work should build on the visibility and capability infrastructure tracked separately rather than mixing behavior changes with diagnostic presentation.
