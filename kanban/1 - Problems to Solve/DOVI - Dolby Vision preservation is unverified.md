# DOVI - Dolby Vision preservation is unverified

## user value

As a viewer, I want compatible Dolby Vision video to retain its intended presentation, so that Freya does not silently discard dynamic-range quality my device and display can present.

## Problem description

Freya currently reduces Dolby Vision evidence to broad provider labels such as Plex's `DOVIPresent` value or Jellyfin's reported video-range fields. Playback compatibility is then decided from a generic HEVC or AV1 codec check. Those values do not establish the Dolby Vision profile, level, compatibility identifier, base and enhancement-layer arrangement, sample entry, or whether required metadata survives provider delivery.

Dolby Vision compatibility varies materially across source types. Streaming-oriented single-layer media, backward-compatible profiles, and dual-layer UHD Blu-ray sources are not interchangeable. Apple platform and HLS support also varies by codec, profile, operating system, device, and display route. A server may direct stream the base codec while dropping, changing, or incorrectly signaling the Dolby Vision metadata.

The desired outcome is for Freya to retain Dolby Vision only when the exact source, server output, native device, and display route form a verified compatible path. Unsupported or uncertain Dolby Vision must fall back to the best compatible presentation without claiming that Dolby Vision survived.

## Status, notes, context, etc

- Split from VREM so the high-value HEVC remux work does not depend on solving every Dolby Vision profile and provider behavior.
- This card owns Dolby Vision carried by HEVC or AV1. AVRM excludes Dolby Vision AV1, and HDPL separately owns HDR10+.
- Current evidence: playback models expose a presence flag or display label but do not retain enough Dolby Vision profile, level, compatibility, and layer information to prove playback support. The delivered HLS parser also does not inspect `SUPPLEMENTAL-CODECS` or cross-check it with `VIDEO-RANGE`.
- Apple documents baseline Dolby Vision HLS profile requirements and newer backward-compatible signaling in the [HLS authoring specification](https://developer.apple.com/documentation/http-live-streaming/hls-authoring-specification-for-apple-devices/) and its [appendixes](https://developer.apple.com/documentation/http-live-streaming/hls-authoring-specification-for-apple-devices-appendixes/).
- Continuation guidance: inventory the exact Dolby Vision metadata Plex and Jellyfin expose for representative Profile 5, 7, 8.1, and 8.4 sources before changing playback decisions. Separately establish what each server delivers when direct play, remux, or conversion is requested.
- Do not equate an HDR-eligible display, generic HEVC/AV1 decode support, a Dolby Vision source label, or a server copy decision with end-to-end Dolby Vision presentation. Preserve a compatible HDR or SDR fallback when any required evidence is absent.
- Validation should distinguish source profile and layers, delivered codec and supplemental signaling, actual server decisions, supported and unsupported display routes, and what Freya reports to the viewer. Provider fixtures and portable decision tests are required; real Dolby Vision hardware and representative media are necessary for final presentation validation.

## Prompts

ok lets do NATP, or at least the low hanging fruit of it. we just did FMTV, so we should have some tools we can use. if you consider any formats not low hanging fruit, then exclude them from NATP and add new card(s) for those

Originally tracked Dolby Vision as part of the advanced-video work split from NATP.

hwo about VREM -- easy ? worth it?

Identified Dolby Vision as worthwhile only after the common HEVC remux case and too profile- and route-dependent to keep in that bounded work.

ok cool makes sense. can you split it into separate cards and include good details and instructions for the next agent,

Created DOVI with profile, provider-delivery, signaling, fallback, and hardware-validation context for the next agent.
