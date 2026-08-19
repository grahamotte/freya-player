# Playback formats and device capabilities are unclear

## user value

As a viewer, I want to understand the source media, the format Freya will actually play, and my device's native playback capabilities, so that I can tell whether playback preserves the quality of my media.

## Problem description

Freya currently reports only a coarse video or audio transcoding label. It does not consistently identify the source container, video, audio, HDR, channel, and subtitle formats, and it does not explain conversions as a source-to-output relationship. The player description can mention a target codec, but it does not provide the complete playback path or distinguish unchanged tracks from remuxed and transcoded tracks.

Freya also has compatibility decisions embedded in provider and platform code without a user-visible account of what the current Apple device reports it can play. This makes successful native playback difficult to verify and makes unexpected transcoding difficult to diagnose.

The desired outcome is for play options and the stock player description to clearly summarize the known source formats and every expected conversion, while the server settings experience exposes the native media capabilities detected on the current device. Unknown or conditional capabilities must be represented honestly rather than presented as guaranteed support.

## Status, notes, context, etc

- This card covers visibility and capability-detection infrastructure, not broader direct-play enablement.
- Playback decisions are made independently by the Plex and Jellyfin connectors and must use a shared app-owned presentation model.
- The information shown before playback is necessarily an expectation based on server metadata and negotiation. It must not be mislabeled as runtime-verified output.
