---
name: version bump
description: Bump Freya Player's app version by looking at commits since the last version bump, choosing a semantic version change, and updating the Xcode project version numbers.
---

# Version Bump

Use this skill when the user wants to bump Freya Player's version.

Do the analysis yourself. Do not add or run a repo helper script for this skill.

Workflow:

1. Find the most recent commit whose subject is exactly `Version`.
2. Review the commits since that point, then inspect the actual code diff if the commit subjects are not enough.
3. Choose the smallest sensible semantic version bump:
   - `major` for intentional breaking changes.
   - `minor` for new user-visible capability.
   - `patch` for fixes, polish, refactors, and internal work that does not expand capability.
4. Update every `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `freya-player.xcodeproj/project.pbxproj`.
5. Run `mise build`.
6. If `mise build` passes, commit the version bump with the subject `Version`.
7. Report the old version, new version, and the short reasoning.

Guidance:

- Prefer judgment over commit-message rules. Read the code when needed.
- Default to the smaller bump when the change is ambiguous.
- Keep the version bump commit subject as `Version` so the next bump has a clean boundary.
- Do not run `mise start` for this skill.
