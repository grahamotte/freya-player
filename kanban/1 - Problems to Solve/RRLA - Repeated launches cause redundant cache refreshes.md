# RRLA - Repeated launches cause redundant cache refreshes

## user value

As a Freya tester, I want repeated app launches to avoid unnecessary cache refreshes, so that opening and closing the app remains quick while cached media still stays current.

## Problem description

Freya currently refreshes its cache whenever the app loads and then every ten minutes while it remains open. During testing, the app is opened and closed frequently, so each launch starts another refresh even when a recent launch already refreshed the cache. This makes routine testing feel unnecessarily clunky.

The refresh schedule does not account for how recently a cache refresh started across app launches. The desired outcome is for Freya to check cache freshness regularly while avoiding a refresh when one has started within the last fifteen minutes.

## Prompts

> add a card for this: can you update the auto refresh so instead of refreshing when the app loads + every 10 min, we do a check once a min and if the cache hasn't been refreshed in the last 15 minutes, then we do a refresh. we'll need to store some "refresh last started at time".&#x20;
>
> this is because when testing, you open/close the app a lot and a refresh every time is super clunky

Created a problem card describing redundant cache refreshes during repeated app launches and the desired cache-freshness behavior.
