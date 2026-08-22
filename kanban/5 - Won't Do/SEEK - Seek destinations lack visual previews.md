# Seek destinations lack visual previews

## user value

As a viewer, I want visual feedback while seeking through a video, so that I can quickly recognize and select the moment I want to watch.

## Problem description

When a viewer seeks through a stream, Freya shows the timeline position but not what the video looks like at that point. The viewer must estimate where a scene begins, resume playback, and seek again if the estimate was wrong. This makes navigating long videos or finding a specific moment slower and less precise.

Some media players show a small thumbnail or tile preview near the current seek position. It is not yet known whether Plex, Jellyfin, the available media streams, and Apple's playback frameworks expose suitable preview imagery across Freya's supported platforms.

The desired outcome is for viewers to receive useful visual feedback about the destination while seeking whenever the media and platform can support it, with clear and consistent behavior when previews are unavailable.

## Status, notes, context, etc

Apple's stock playback controls display seek thumbnails when an HLS multivariant playlist advertises an Apple-compatible I-frame-only rendition with `EXT-X-I-FRAME-STREAM-INF`. Freya already uses `AVPlayerViewController`, so a compatible rendition supplied by the stream requires no additional player UI code.

Plex exposes generated preview images through BIF index endpoints. Jellyfin exposes trickplay as tiled JPEG images and an `EXT-X-IMAGE-STREAM-INF` playlist. Neither format is an Apple-compatible I-frame rendition, and the stock player provides no public API for supplying individual thumbnails or observing the live scrub destination. The existing tvOS navigation delegate methods run only once when the viewer finishes navigating and playback is about to resume.

A complete Freya-side implementation would therefore require custom playback controls, including a custom timeline, on each supported platform. Preserving the stock player instead requires Plex and Jellyfin to serve Apple-compatible I-frame HLS renditions; Jellyfin can currently gain that behavior through a third-party server plugin, while Plex would still need a compatible server-side bridge.

Freya will not replace Apple's playback controls to translate provider-specific preview formats. The custom player surface and platform-specific interaction work would be disproportionate to the benefit and would trade away stock platform behavior. Seek previews remain available automatically whenever a server supplies an Apple-compatible I-frame HLS rendition.

## Prompts

> can we do SEEK?

Work started by investigating native Apple playback support and the preview imagery exposed by Plex and Jellyfin.

> yep put the context notes and decision in the card and move it to wont do

Recorded the platform and provider constraints, documented the decision to preserve Apple's stock playback controls, and moved the card permanently to Won't Do.
