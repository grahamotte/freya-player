# HDPL - HDR10+ preservation is unverified

## user value

As a viewer, I want compatible HDR10+ video to retain its dynamic metadata, so that playback uses the presentation intended for my supported display instead of silently degrading to static HDR10 or SDR.

## Problem description

Freya currently recognizes PQ transfer characteristics as HDR10 and has no end-to-end evidence that HDR10+ dynamic metadata is present, retained by Plex or Jellyfin, correctly described by the delivered stream, and presented by the active Apple device and display. A generic HEVC, AV1, PQ, HDR, or HDR10 label does not distinguish HDR10+ from its static fallback.

Provider remuxing can retain the base video while losing or failing to signal HDR10+ metadata. Apple HLS uses codec and supplemental signaling for advanced backward-compatible formats, while actual presentation remains dependent on the device, operating system, and display route. Consequently, apparently successful stream copy is not sufficient evidence that HDR10+ survived.

The desired outcome is for HDR10+ to be preserved and reported only when its dynamic metadata survives the complete native playback path. Otherwise Freya should accurately describe and deliver the compatible HDR10 or SDR result rather than claiming HDR10+.

## Status, notes, context, etc

- Split from VREM because HDR10+ detection and signaling are independent from basic HEVC/HDR10/HLG remux compatibility.
- This card owns HDR10+ regardless of whether its base codec is HEVC or AV1. AVRM excludes HDR10+ AV1, and DOVI separately owns Dolby Vision.
- Current evidence: `MediaTranscoding` canonicalizes PQ transfer characteristics to HDR10, provider playback models do not establish HDR10+ metadata, and the HLS parser does not inspect `SUPPLEMENTAL-CODECS` compatibility brands.
- Apple's current advanced HLS signaling, including the `cdm4` compatibility brand used to indicate HDR10+ metadata, is documented in the [HLS authoring specification appendixes](https://developer.apple.com/documentation/http-live-streaming/hls-authoring-specification-for-apple-devices-appendixes/).
- Continuation guidance: first establish which Plex and Jellyfin metadata fields reliably identify HDR10+ sources and whether each server preserves the dynamic metadata under direct play, remux, and conversion. Treat the delivered stream and real presentation as distinct validation boundaries.
- Do not infer HDR10+ from PQ, Main 10, ten-bit video, HDR eligibility, or an HDR-capable display. Unknown cases must remain labeled as HDR10 or the actual fallback delivered by the server.
- Validation should include representative HDR10+ and ordinary HDR10 fixtures, both providers, direct and server-streamed paths, servers that preserve or discard the metadata, supported and unsupported output routes, and user-visible format reporting. Final confirmation requires compatible hardware and media.

## Prompts

ok lets do NATP, or at least the low hanging fruit of it. we just did FMTV, so we should have some tools we can use. if you consider any formats not low hanging fruit, then exclude them from NATP and add new card(s) for those

Originally tracked HDR10+ as part of the advanced-video work split from NATP.

hwo about VREM -- easy ? worth it?

Identified HDR10+ as a metadata-preservation problem that should not block the common HEVC remux case.

ok cool makes sense. can you split it into separate cards and include good details and instructions for the next agent,

Created HDPL with source-identification, provider-delivery, signaling, fallback, reporting, and hardware-validation context for the next agent.
