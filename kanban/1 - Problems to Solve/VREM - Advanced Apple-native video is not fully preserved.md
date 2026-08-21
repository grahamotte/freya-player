# VREM - Advanced Apple-native video is not fully preserved

## user value

As a viewer, I want advanced video formats to be retained whenever my complete playback path supports them, so that direct or server-streamed playback does not unnecessarily reduce picture quality.

## Problem description

Freya currently treats broad HEVC detection as sufficient for direct playback without separately establishing the source profile and dynamic-range variant. When Plex or Jellyfin cannot deliver the original MP4-family file, the server-streaming path produces MPEG-TS HLS with H.264 video. This converts HEVC and AV1 even when the device reports native support, and it can remove HDR10, HDR10+, HLG, or Dolby Vision presentation that direct playback might retain.

Support cannot be inferred from the broad HEVC or HDR label alone. It varies with codec profile, bit depth, dynamic-range metadata, device hardware, operating system, display route, provider behavior, and the server's available stream.

The desired outcome is for video that the active device and display route can present natively to retain its codec, resolution, bitrate, and dynamic range during both direct and server-streamed playback, without claiming support for unverified profiles or producing an unplayable stream.

## Status, notes, context, etc

- Split from NATP because broad direct-file codec detection does not establish advanced profile support, and server-stream delivery needs separate provider validation.
- This card covers HEVC and AV1 profile limits plus HDR10, HDR10+, HLG, and Dolby Vision during direct and server-streamed playback.

## Prompts

ok lets do NATP, or at least the low hanging fruit of it. we just did FMTV, so we should have some tools we can use. if you consider any formats not low hanging fruit, then exclude them from NATP and add new card(s) for those

Split advanced native-video preservation out of NATP because generic codec detection cannot safely establish profile and dynamic-range support and the current provider paths always produce MPEG-TS/H.264 when server streaming is needed.
