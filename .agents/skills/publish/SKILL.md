---
name: publish
description: Version and publish Code Moto across its configured Apple targets, repository releases, and App Store Connect. Use only when the user explicitly invokes `$publish` or asks to use the publish skill by name.
---

# Publish

1. Require a clean worktree on `master`. Read `apps/config.json` for the current version and configured targets.
2. Review the commits since the most recent commit named `Version` and choose the smallest appropriate semantic version bump from the current configured version: major for breaking changes, minor for new user-facing capabilities, and patch for everything else. Ask before a major bump. A publish request permits a patch release when there are no notable changes.
3. Before changing the version, run `mise deploy:approved-version` to find the latest version actually approved by App Store Connect. Find the `Version` commit that set that approved version and review every subsequent change when writing `whatsNew`, including changes already included in newer unapproved versions. If no approved version exists, review changes from the beginning of the repository. Write a concise, user-facing summary based on that full range, using `Bug fixes.` when nothing user-facing is notable. Run `mise deploy:set-version <version>` and `mise test`, then commit only the version files with the message `Version`.
4. Run `mise deploy:publish` and follow it until every configured target finishes. If the user requested a TestFlight-only publish, run `mise deploy:publish --no-review`; upload the build without changing App Store versions, metadata, review details, or review submissions. Let the task perform its own push and publishing stages; do not reproduce stages manually or edit its cache. If App Store Connect is still processing a build, wait and rerun the same command so it can resume.
5. If anything else fails, stop publishing and help the user diagnose it before proceeding. Make the failure immediately clear, focus on the error and its impact, inspect the relevant logs and state, and work with the user on recovery instead of presenting a routine release summary.
6. When publishing succeeds, briefly report the version, release notes, version commit, repository releases, and App Store status for each target.

The macOS revision is signed, notarized, and released through the configured repository hosts. Other Apple targets are distributed through App Store Connect. `--no-review` uploads App Store builds for TestFlight but skips App Store version preparation and review submission. Report those App Store builds as uploaded for TestFlight, not prepared or submitted for review.
