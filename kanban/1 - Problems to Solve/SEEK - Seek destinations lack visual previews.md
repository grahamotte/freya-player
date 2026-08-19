# Seek destinations lack visual previews

## user value

As a viewer, I want visual feedback while seeking through a video, so that I can quickly recognize and select the moment I want to watch.

## Problem description

When a viewer seeks through a stream, Freya shows the timeline position but not what the video looks like at that point. The viewer must estimate where a scene begins, resume playback, and seek again if the estimate was wrong. This makes navigating long videos or finding a specific moment slower and less precise.

Some media players show a small thumbnail or tile preview near the current seek position. It is not yet known whether Plex, Jellyfin, the available media streams, and Apple's playback frameworks expose suitable preview imagery across Freya's supported platforms.

The desired outcome is for viewers to receive useful visual feedback about the destination while seeking whenever the media and platform can support it, with clear and consistent behavior when previews are unavailable.
