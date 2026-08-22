# DHDR - Dynamic HDR preservation is unverified

## user value

As a viewer, I want compatible Dolby Vision and HDR10+ video to retain its dynamic presentation, so that Freya does not silently reduce it to static HDR or SDR.

## Problem description

Freya can identify broad Dolby Vision or PQ/HDR labels, but those labels do not prove that Dolby Vision or HDR10+ metadata survives Plex or Jellyfin delivery and reaches a compatible Apple device and display. Profiles, compatibility identifiers, layers, dynamic metadata, HLS signaling, provider behavior, and the display route all affect the result.

The desired outcome is to preserve and report HEVC Dolby Vision or HDR10+ only when the complete native playback path supports it. Other cases must accurately fall back to the retained HDR10, HLG, or SDR presentation.

## Status, notes, context, etc

- Order: 2 of 3. Start after VREM so this card extends its proven HEVC fragmented-MP4 path rather than creating another transport path.
- Scope: Dolby Vision and HDR10+ carried by HEVC. Ordinary HEVC SDR/HDR10/HLG belongs to VREM. AV1 and dynamic HDR carried by AV1 are excluded.
- Extend the same common model established by VREM. `PlaybackCompatibility` owns exact Apple device and route support; `MediaTranscoding` owns normalized dynamic-range formats and parsing of delivered HLS attributes such as `CODECS`, `VIDEO-RANGE`, and `SUPPLEMENTAL-CODECS`.
- Plex and Jellyfin should provide their source metadata and provider decisions to the common path, while their request construction remains connector-specific. Do not infer final playback from provider source labels.
- `MediaPlaybackOptions` may predict the intended result, but the server decision and delivered manifest must determine what Freya ultimately reports. Never label playback Dolby Vision or HDR10+ when the dynamic metadata or required signaling is unverified.
- Preserve a compatible HDR10, HLG, or SDR fallback. Do not let dynamic-HDR uncertainty regress the HEVC remux behavior completed by VREM.
- Cover both providers, Dolby Vision and HDR10+ sources, ordinary HDR10 controls, retained and stripped metadata, compatible and incompatible routes, fallback reporting, and delivered-manifest parsing. Real dynamic-HDR confirmation requires representative media, hardware, and displays.
- Platform references: [Apple HLS authoring specification](https://developer.apple.com/documentation/http-live-streaming/hls-authoring-specification-for-apple-devices/) and [appendixes](https://developer.apple.com/documentation/http-live-streaming/hls-authoring-specification-for-apple-devices-appendixes/).
