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
- Scope for this card is capability-gated direct play of MP4-family H.264, HEVC, hardware-decoded AV1, AAC, MP3, AC-3, E-AC-3, ALAC, and FLAC, plus HLS stream copy of detected H.264, AAC, MP3, AC-3, and E-AC-3.
- Advanced HEVC and AV1 profiles plus HDR variants during direct or server-streamed playback are tracked by VREM and excluded from this card.
- Lossless and spatial audio preservation beyond the safe HLS codecs is tracked by AUDP and excluded from this card.
- In review: Plex and Jellyfin now use the AVFoundation capability checks introduced by FMTV for direct-play codec decisions instead of fixed codec assumptions.
- In review: Compatible AC-3 and E-AC-3 tracks are copied through provider HLS streams instead of always being converted to AAC, while the tvOS prerelease audio workaround still forces conversion where needed.
- Verified with `mise test` and unsigned generic tvOS, iOS, and Mac Catalyst builds.

## Prompts

ok lets do NATP, or at least the low hanging fruit of it. we just did FMTV, so we should have some tools we can use. if you consider any formats not low hanging fruit, then exclude them from NATP and add new card(s) for those

Moved NATP into progress, used FMTV's AVFoundation detection in both providers' playback decisions, enabled device-supported direct formats and safe HLS AC-3/E-AC-3 copying, and split harder video-remux and advanced-audio cases into VREM and AUDP.

NATP looks good - commit it

Moved the approved NATP work to Done and committed the capability-gated playback changes with the VREM and AUDP follow-up cards.
