# AVRM - AV1 video is unnecessarily transcoded during server streaming

## user value

As a viewer with an AV1-capable Apple device, I want compatible AV1 video to remain intact during server streaming, so that Freya preserves quality without an unnecessary server encode.

## Problem description

Freya capability-gates AV1 direct play, but its Plex and Jellyfin server-streaming paths always request MPEG-TS/H.264. Compatible AV1 is therefore converted whenever direct file delivery is unavailable, even though Apple supports conforming AV1 HLS in fragmented MP4 on suitable hardware.

The desired outcome is to retain compatible AV1 SDR, HDR10, and HLG video during server streaming, with the existing H.264 path used when AV1 hardware, source parameters, provider delivery, or presentation is unsupported or uncertain.

## Status, notes, context, etc

- Order: 3 of 3. Start after VREM and DHDR; reuse their shared container, format, manifest, reporting, and fallback behavior.
- Scope: AV1 SDR, HDR10, and HLG. Dolby Vision and HDR10+ carried by AV1 are excluded.
- Extend `PlaybackCompatibility` for exact AV1 source and hardware decisions instead of relying only on a generic codec label. Reuse the fragmented-MP4 and provider-neutral streaming representation established by VREM.
- Keep AV1 format normalization and delivered HLS parsing in `MediaTranscoding`, and keep predicted remux/transcode reporting in `MediaPlaybackOptions` and `MediaPlaybackPlan`. Do not add a parallel AV1-specific transcoding model.
- Plex and Jellyfin should translate their AV1 metadata into the common decision and construct provider-specific requests. The actual server decision and delivered manifest remain authoritative for final format reporting.
- Preserve the H.264 fallback when hardware decode, profile, level, bit depth, chroma format, resolution, dynamic range, or provider delivery cannot be established safely.
- Cover hardware-decoder present and absent cases, compatible and incompatible AV1, both providers, SDR/HDR10/HLG, container-only remuxing, H.264 fallback, delivered manifests, and playback reporting. Final performance and presentation checks require representative AV1 hardware and media.
- Platform reference: [Apple HLS authoring specification](https://developer.apple.com/documentation/http-live-streaming/hls-authoring-specification-for-apple-devices/).
