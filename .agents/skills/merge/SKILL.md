---
name: merge
description: Merge the latest Code Moto into a downstream repository without rewriting its history. Use only when the user explicitly invokes `$merge` or asks to use the merge skill by name.
---

# Workflow

1. Before starting the merge, run the `merge-precheck` skill. If the precheck fails, abort the merge.
2. Record `git rev-parse HEAD` and echo it to the user as the merge recovery point.
3. Run `mise merge`.
4. If it stops with conflicts, inspect the output and repository state. Resolve every conflict, stage the resolutions, and run `GIT_EDITOR=true git merge --continue`. Repeat until the merge finishes.
5. Preserve the intent of both Code Moto and downstream changes. Inspect surrounding code, history, and tests when a resolution is not obvious.
6. Ask the user only when there is genuine ambiguity with materially different valid outcomes, or progress requires information or authority only they can provide. Explain the exact decision needed; do not stop merely because a conflict or failure occurred.
7. Run `mise test` after the merge succeeds. Fix merge-related failures and rerun the whole suite until it passes.
8. Report the completed merge, conflict resolutions, merge commit, and test results.
