# VREM - HEVC video is unnecessarily transcoded during server streaming

## user value

As a viewer, I want compatible HEVC video to remain intact during server streaming, so that Freya preserves picture quality without burdening my server with an unnecessary video encode.

## Problem description

Freya can direct play device-supported HEVC from compatible MP4-family files, but its Plex and Jellyfin server-streaming paths currently request MPEG-TS with H.264. HEVC in a common incompatible container such as MKV is therefore converted even when only remuxing is needed. This can also discard HDR10 or HLG presentation.

The desired outcome is to retain compatible HEVC SDR, HDR10, and HLG video during server streaming, while preserving the existing H.264 fallback whenever the device, source, display route, or provider output is incompatible or uncertain.

## Status, notes, context, etc

- Order: 1 of 3. Complete this before DHDR and AVRM because it establishes the shared fragmented-MP4 streaming path they build on.
- Scope: HEVC SDR, HDR10, and HLG during server streaming. Dolby Vision and HDR10+ belong to DHDR. AV1 belongs to AVRM.
- Apple requires HEVC HLS to use fragmented MP4. Freya currently limits `PlaybackCompatibility.streamingVideoCodecs` to H.264, requests `segmentContainer=ts` and `videoCodec=h264` from Jellyfin, and advertises MPEG-TS/H.264 to Plex.
- Keep Apple capability checks in `PlaybackCompatibility`. Keep normalized containers, video formats, dynamic-range names, and delivered HLS parsing in `MediaTranscoding`. Let `MediaPlaybackOptions` and `MediaPlaybackPlan` describe the predicted remux or transcode using those common formats.
- Plex and Jellyfin should translate provider metadata into the shared decision and then build their own requests. Do not duplicate Apple codec rules in provider code or expose provider response models outside their connector.
- Treat the server decision and delivered manifest as authoritative for the displayed playback formats. A source HEVC label alone does not prove that the server retained HEVC or HDR.
- Cover both providers, compatible and incompatible HEVC, SDR/HDR10/HLG, container-only remuxing, audio-only conversion, the H.264 fallback, and actual delivered-format reporting. Run `mise test` and the same generic unsigned Apple builds used by NATP.
- Platform reference: [Apple HLS authoring specification](https://developer.apple.com/documentation/http-live-streaming/hls-authoring-specification-for-apple-devices/).
