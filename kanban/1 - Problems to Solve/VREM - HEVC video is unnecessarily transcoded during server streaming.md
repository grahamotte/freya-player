# VREM - HEVC video is unnecessarily transcoded during server streaming

## user value

As a viewer, I want compatible HEVC video to remain intact during server streaming, so that container or track incompatibilities do not reduce picture quality or make my server re-encode video unnecessarily.

## Problem description

NATP allows device-detected HEVC to direct play from compatible MP4-family files. When Plex or Jellyfin cannot deliver the original file, however, Freya's server-streaming path only considers H.264 copyable and requests MPEG-TS/H.264 output. Common HEVC media in MKV therefore requires video transcoding when only its container, audio, selected track, subtitle delivery, or connection limit prevents direct play. Static HDR10 or HLG presentation can be lost with the codec conversion.

HEVC compatibility cannot be inferred from a broad codec label. Main versus Main 10 profile, level, tier, bit depth, chroma format, sample entry, resolution, frame rate, dynamic-range metadata, device hardware, operating system, display route, provider behavior, and actual server output all affect native playback. Apple's HLS requirements allow HEVC, HDR10, and HLG, but require HEVC video to use fragmented MP4 rather than the transport-stream path Freya currently requests.

The desired outcome is for compatible HEVC SDR, HDR10, and HLG video to retain its codec, resolution, bitrate, and dynamic range during direct or server-streamed playback. An unrelated incompatibility must not force video conversion when the server can deliver a native stream, while uncertain or incompatible cases must continue to receive a playable fallback.

## Status, notes, context, etc

- Split from NATP because direct-file codec detection does not prove that Plex or Jellyfin can retain the same video through server streaming.
- This card is limited to HEVC SDR, static HDR10, and HLG. DOVI owns Dolby Vision, HDPL owns HDR10+, and AVRM owns AV1.
- Current evidence: `PlaybackCompatibility.streamingVideoCodecs` reduces detected native support to H.264; Jellyfin requests `segmentContainer=ts` and `videoCodec=h264`; Plex advertises an HLS MPEG-TS/H.264 target.
- Apple states that HEVC HLS must use fragmented MP4, supports Main 10 through defined profile and level limits, and permits HDR10 or HLG dynamic range: [HLS authoring specification](https://developer.apple.com/documentation/http-live-streaming/hls-authoring-specification-for-apple-devices/).
- Continuation guidance: read FMTV and NATP in Done before starting, and follow their capability-detection and provider-decision test patterns. Treat source metadata, server decisions, delivered HLS signaling, and successful native presentation as separate evidence; none alone proves the complete path.
- Preserve the existing H.264 fallback whenever capability or server delivery is unknown. Validation should cover Plex and Jellyfin, direct and server-streamed playback, SDR/HDR10/HLG, compatible and incompatible profiles, container-only remux cases, audio-only conversion cases, and the actual formats reported after server negotiation.
- Unit-test portable compatibility and provider decisions, run `mise test`, and perform the generic unsigned Apple builds used by NATP. Real-device HDR presentation remains a user validation step unless suitable hardware is available.

## Prompts

ok lets do NATP, or at least the low hanging fruit of it. we just did FMTV, so we should have some tools we can use. if you consider any formats not low hanging fruit, then exclude them from NATP and add new card(s) for those

Split advanced native-video preservation out of NATP because generic codec detection cannot safely establish profile and dynamic-range support and the current provider paths always produce MPEG-TS/H.264 when server streaming is needed.

hwo about VREM -- easy ? worth it?

Assessed the common HEVC remux case as worthwhile and moderate, while identifying Dolby Vision, HDR10+, and AV1 as harder independent compatibility problems.

ok cool makes sense. can you split it into separate cards and include good details and instructions for the next agent,

Narrowed VREM to HEVC SDR/HDR10/HLG and recorded the current transport constraints, authoritative platform requirements, scope boundaries, fallback expectations, and validation guidance for continuation.
