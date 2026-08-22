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
- Implemented a shared fragmented-MP4 HLS representation and normalized delivered `CODECS`, `VIDEO-RANGE`, and segment-container reporting.
- Plex and Jellyfin now request fragmented MP4 and advertise HEVC only for compatible automatic-quality stream copying. H.264 remains the target for incompatible sources, routes, profiles, levels, bit depths, interlaced video, and explicit unsupported or uncertain dynamic ranges.
- Compatible HEVC SDR, HDR10, and HLG preserve video through container-only remuxes and audio-only conversions. Dolby Vision, HDR10+, and AV1 remain excluded for their follow-up cards.
- Confirmed that the H.264-to-H.264 screenshot was caused by `bt709` falling through as an unknown dynamic range. The play-options sheet was showing Freya's predicted plan; the bad classification also disabled video stream copying in the provider requests.
- Normalized the standard SDR transfer-characteristic aliases used by FFmpeg and media servers, including BT.709, BT.470, SMPTE 170M/240M, IEC 61966, BT.1361, and BT.2020 SDR transfer functions. Unknown and unusual transfer types still use the conservative H.264 fallback.
- Authenticated against the configured Plex server and confirmed multiple live Matroska/H.264 sources report `bt709`. The saved Jellyfin token is currently removed, so that provider path was verified through decoded production-model regression tests instead of a live request.
- Verified with the full `mise test` suite and unsigned generic iOS, tvOS, and Mac Catalyst builds.

## Prompts

do VREM

Moved VREM into progress, implemented the shared fragmented-MP4 HEVC streaming path for Plex and Jellyfin, added capability and delivered-format regression coverage, passed the full repository suite and all three unsigned generic Apple builds, and moved the completed work to review.

is that actually what is happening? if so can you fix? can you also see if there are similar issues like this?

Confirmed that BT.709 was incorrectly treated as an unknown dynamic range and caused the H.264-to-H.264 prediction and provider stream-copy rejection. Normalized the related standard SDR transfer aliases, added shared and Jellyfin end-to-end regression coverage, validated live Plex metadata, passed the full suite and all Apple builds, and returned VREM to review.

op commit the current change

Approved the completed VREM work, moved the card to Done, and committed the implementation and verification coverage together.
