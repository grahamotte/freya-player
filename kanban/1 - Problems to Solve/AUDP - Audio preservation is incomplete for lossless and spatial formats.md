# AUDP - Audio preservation is incomplete for lossless and spatial formats

## user value

As a viewer, I want lossless and spatial audio to remain intact whenever my device and output route support it, so that server streaming does not unnecessarily reduce audio quality or presentation.

## Problem description

NATP can safely retain device-detected ALAC and FLAC in directly playable MP4-family files and can copy AAC, MP3, AC-3, and E-AC-3 through the current HLS path. ALAC and FLAC still become AAC when server streaming is required, while an E-AC-3 label alone does not establish whether Dolby Atmos metadata will survive delivery or whether the active audio route can present it.

Other lossless or spatial source labels likewise do not prove native AVPlayer compatibility. Container metadata, codec variants, operating system behavior, provider output, and the active speaker or receiver route all affect the result.

The desired outcome is for Freya to preserve lossless and spatial audio only when native delivery and presentation are established for the complete playback path, and otherwise request the narrowest compatible audio conversion without forcing a video conversion.

## Status, notes, context, etc

- Split from NATP because direct codec detection does not establish lossless HLS delivery or route-dependent spatial presentation.
- This card includes ALAC, FLAC, Dolby Atmos, and other lossless or spatial variants not covered by NATP's safe direct-play and HLS-copy set.

## Prompts

ok lets do NATP, or at least the low hanging fruit of it. we just did FMTV, so we should have some tools we can use. if you consider any formats not low hanging fruit, then exclude them from NATP and add new card(s) for those

Split lossless server-streaming and route-dependent spatial-audio preservation out of NATP because codec labels alone cannot establish compatible delivery or output.
