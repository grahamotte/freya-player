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

## Prompts

ok lets do NATP, or at least the low hanging fruit of it. we just did FMTV, so we should have some tools we can use. if you consider any formats not low hanging fruit, then exclude them from NATP and add new card(s) for those

Originally tracked AV1 preservation in the work split from NATP.

hwo about VREM -- easy ? worth it?

Identified AV1 as a separate hardware- and delivery-dependent follow-up.

ok cool makes sense. can you split it into separate cards and include good details and instructions for the next agent,

Created AVRM separately from HEVC and dynamic HDR.

1 VREM: HEVC, HDR10, and HLG.
2 Dynamic HDR card: combine DOVI and HDPL.
3 AVRM: AV1 SDR, HDR10, and HLG.

ok lets split this way. and mention the order in the cards. rewrite the cards as new ordered and focused cards focused just on their change without all the cruft in the current cards so the agent stays focused. include some broad implimentation details in this so there is cohesive design across the cards - particularly the use of the common transcoding module and stuff

Rewrote AVRM as the third focused card, explicitly reusing VREM and DHDR's common transcoding and playback-reporting design.
