# AVRM - AV1 video is unnecessarily transcoded during server streaming

## user value

As a viewer with an AV1-capable Apple device, I want compatible AV1 video to remain intact during server streaming, so that Freya does not reduce quality or burden my server with an unnecessary video encode.

## Problem description

NATP permits AV1 direct play only when AVFoundation reports a representative AV1 format as playable and VideoToolbox reports a hardware decoder. When the original MP4-family file cannot be delivered directly, Freya's Plex and Jellyfin streaming paths request MPEG-TS/H.264 and therefore convert AV1 even on hardware that could decode an Apple-compatible AV1 HLS stream.

Generic AV1 and hardware-decoder checks do not prove that a particular source is compatible. Profile, level, tier, bit depth, chroma subsampling, resolution, frame rate, dynamic range, container metadata, device generation, and actual server output matter. Apple's HLS requirements permit AV1 only in fragmented MP4 and impose a level limit, while provider support for retaining AV1 during streaming still needs independent evidence.

The desired outcome is for compatible AV1 video to retain its codec, resolution, bitrate, and ordinary SDR or static-HDR presentation during direct or server-streamed playback, with a reliable playable fallback on unsupported devices or when the server cannot deliver a conforming stream.

## Status, notes, context, etc

- Split from VREM so AV1 hardware and delivery validation does not block the much more common HEVC remux case.
- This card covers ordinary AV1 SDR, HDR10, and HLG compatibility. DOVI owns Dolby Vision carried by AV1, and HDPL owns HDR10+ carried by AV1.
- Current evidence: direct play uses one representative AV1 MIME type plus a hardware-decoder check; `streamingVideoCodecs` excludes AV1; Jellyfin requests MPEG-TS/H.264; Plex advertises an HLS MPEG-TS/H.264 target.
- Apple requires AV1 HLS video to use fragmented MP4 and limits it to Level 6.2 in the current [HLS authoring specification](https://developer.apple.com/documentation/http-live-streaming/hls-authoring-specification-for-apple-devices/).
- Continuation guidance: establish the AV1 profiles actually reported by Plex and Jellyfin, the hardware and operating systems on which the representative format check is trustworthy, and what each server delivers under direct play, remux, and conversion before broadening compatibility claims.
- A generic AV1 label, software decode possibility, or conforming source does not prove that the active server can produce a conforming stream. Preserve the existing H.264 fallback when hardware, source parameters, or server delivery are uncertain.
- Validation should cover hardware-decoder present and absent cases, compatible and incompatible source parameters, both providers, direct and server-streamed paths, actual delivered manifests, and accurate playback reporting. Portable decisions require unit tests; final performance and presentation checks require representative AV1 hardware and media.

## Prompts

ok lets do NATP, or at least the low hanging fruit of it. we just did FMTV, so we should have some tools we can use. if you consider any formats not low hanging fruit, then exclude them from NATP and add new card(s) for those

Originally tracked AV1 as part of the advanced-video work split from NATP.

hwo about VREM -- easy ? worth it?

Identified AV1 as worthwhile only on a narrower hardware set and independent from the common HEVC remux case.

ok cool makes sense. can you split it into separate cards and include good details and instructions for the next agent,

Created AVRM with codec-parameter, hardware, provider-delivery, fallback, reporting, and validation context for the next agent.
