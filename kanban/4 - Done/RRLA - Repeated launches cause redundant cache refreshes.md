# RRLA - Repeated launches cause redundant cache refreshes

## user value

As a Freya tester, I want repeated app launches to avoid unnecessary cache refreshes, so that opening and closing the app remains quick while cached media still stays current.

## Problem description

Freya currently refreshes its cache whenever the app loads and then every ten minutes while it remains open. During testing, the app is opened and closed frequently, so each launch starts another refresh even when a recent launch already refreshed the cache. This makes routine testing feel unnecessarily clunky.

The refresh schedule does not account for how recently a cache refresh started across app launches. The desired outcome is for Freya to check cache freshness regularly while avoiding a refresh when one has started within the last fifteen minutes.

## Status, notes, context, etc

Implemented a persisted, provider-and-server-scoped refresh-start timestamp. Automatic refresh checks now run immediately and once per minute, start a full refresh only when the previous start was at least fifteen minutes ago, and wait for the saved provider connection to be live before recording a start. Manual full refreshes also update the timestamp.

Verified with `mise test` and a code-signing-disabled Mac Catalyst Xcode build. Added coverage for first refresh, the fifteen-minute boundary, provider/server scoping, and clock rollback.

## Prompts

> add a card for this: can you update the auto refresh so instead of refreshing when the app loads + every 10 min, we do a check once a min and if the cache hasn't been refreshed in the last 15 minutes, then we do a refresh. we'll need to store some "refresh last started at time".&#x20;
>
> this is because when testing, you open/close the app a lot and a refresh every time is super clunky

Created a problem card describing redundant cache refreshes during repeated app launches and the desired cache-freshness behavior.

> do RRLA

Implemented persisted refresh freshness checks, changed automatic polling to one minute, guarded launch-time checks until the provider connection is live, added unit coverage, passed the full repository test suite, passed a Mac Catalyst build, and moved RRLA to review.

> LGTM

Recorded approval, moved RRLA to Done, and committed the implementation with the completed card.
