# Playback reloads slowly after a long pause

## user value

As a viewer, I want playback to resume promptly after I have paused for a few minutes, so that I can continue watching without an unexpectedly long interruption.

## Problem description

On tvOS, pausing playback for a few minutes and then pressing play resumes immediately while previously buffered media remains available. Once that buffer is exhausted, playback stalls while more media is loaded. Some reloading at this point is expected, but the stall can last roughly a minute before playback continues.

By comparison, backing out of the player and choosing resume for the same media takes only a few seconds. Resuming an existing paused playback session is therefore substantially slower than leaving and restarting the session at the saved position.

The issue has been observed on tvOS and may affect the other Apple platforms as well. The cause and full platform scope are not yet known.

The desired outcome is for playback after a long pause to recover and continue within a reasonable time comparable to restarting the media at its saved position.

## Status, notes, context, etc

- Observed on tvOS.
- Reproduction: play media, pause for approximately two or more minutes, resume playback, and wait for the existing buffer to run out.
- The initial resume is immediate; the excessive delay occurs when playback needs additional media data.
- Backing out and selecting resume is a useful baseline because it typically starts again within a few seconds.
