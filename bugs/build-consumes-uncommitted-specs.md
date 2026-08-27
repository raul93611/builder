# Build consumes uncommitted specs

`/build` deletes spec files that were never committed, permanently destroying them and their decision logs.

**Status:** `fixed`
**Severity:** High — silent, unrecoverable data loss. The build itself succeeds, so nothing signals that anything was lost.

## Steps to Reproduce

1. Run `/prd`, `/feature`, or `/bug` in a project. Each writes its spec file (`PRD.md`, `features/x.md`, `bugs/y.md`) and stops there — no git step.
2. Do not commit the file by hand.
3. Run `/build`. It creates a branch, builds the work, marks the spec `built` / `fixed`.
4. At the end, `/build` deletes `PRD.md`, every `features/*` marked `built`, and every `bugs/*` marked `fixed`.
5. Try to recover the spec: `git log --all -- features/x.md`, `git fsck --lost-found`, the reflog.

## Expected vs Actual

**Expected:** the spec is recoverable from git history after the build consumes it. That history is the only surviving record of the Decisions log — every choice made during the interview, with reasoning.

**Actual:** nothing to recover. Git never saw the file, so it exists in no object at all — not as a dangling blob, not in the reflog. The deletion is final.

## Second failure, same root cause: `/build-parallel`

`build-parallel.md:71-80` creates worktrees with `git worktree add`, then instructs: "Remove all spec files from `features/` and `bugs/` *except* the one this worktree is responsible for."

A new worktree is a fresh checkout of a branch — untracked files in the main working tree do not come along. With uncommitted specs, every worktree starts with an empty `features/` and `bugs/`. Each headless `/build` inside then sees **zero planned items** and builds nothing, while the orchestrator reads a clean exit as success.

This one fails silently rather than loudly, which makes it the more dangerous half.

## Investigation

Root cause: **no command commits the spec files it writes, and `/build` is the only command that deletes them.**

- `prd.md`, `feature.md`, `bug.md` — each ends at "write the file + update CLAUDE.md". `grep -n 'git |commit|branch' commands/*.md` returns no git operation in any of the three.
- `build.md:24-31` (Git Setup) — creates the build branch, then goes straight to Scaffold. No commit of the inputs.
- `build.md:159-163` (Clean up spec files) — deletes `PRD.md`, built features, fixed bugs. This is the destructive step.
- `build-parallel.md:71-80` (Phase 4) — assumes worktrees inherit spec files they cannot inherit unless tracked.

**Confirmed against this repo's own history.** Building `/gpt` did by hand exactly what `/build` should automate:

```
d5610d1  Spec /gpt …                          features/gpt-review.md | +108
5b89229  feat: add /gpt …                      (the build)
8eea597  chore: remove consumed feature spec   features/gpt-review.md | -108
```

Spec committed, build committed, consumed spec removed in its own commit — the content survives at `d5610d1`. Without that manual discipline the file would be gone.

This is a known, already-recorded failure: the global lesson dated 2026-08-20 records `/build`'s "delete consumed specs" step destroying six specs git had never seen. The lesson was written; the command was never fixed.

## Fix Plan

### `commands/build.md`

**1. Git Setup (`build.md:24-31`) — commit specs immediately after the branch exists.**

Add a step after branch creation: stage the build's inputs **by explicit path** and commit `chore: track specs for this build`.

- Paths: `PRD.md`, each `features/*.md`, each `bugs/*.md`, `CLAUDE.md`.
- **Never `git add -A` or `git add <dir>`** — explicit paths only. Blanket staging is how a live-API harness once ended up in a commit.
- No-op cleanly when the files are already tracked and unchanged (common — the user may have committed them by hand). "Nothing to commit" is a success, not an error.

**2. Fresh-repo case.** A brand-new repo has no root commit to branch from. Order: `git init` → stage the specs → root commit on `main` (`chore: add project specs`) → create the build branch from it. A spec-only root commit is the project baseline, not build work, so this does not violate "never commit directly to main."

**3. Clean up spec files (`build.md:159-163`) — commit the deletion.**

Currently the build ends with uncommitted deletions in the working tree. Add: commit the removal as `chore: remove consumed specs`. Mirrors `8eea597`.

### `commands/build-parallel.md`

**4. Phase 4 (`build-parallel.md:66-80`) — commit specs before creating worktrees.**

Between "Create the integration branch" and "For each selected item, create a worktree", commit all `features/*.md`, `bugs/*.md`, `PRD.md` and `CLAUDE.md` to the integration branch by explicit path. Only then `git worktree add`, so each worktree inherits the specs it is meant to prune.

Phase 4 already says "Confirm the worktree's `CLAUDE.md` is intact" — extend that check to the spec files, and **fail loudly** if a worktree's `features/`/`bugs/` is empty after pruning. A worktree with no planned item must never be handed to a headless build.

### Test

This repo holds prompt files, not code — there is no suite to add to. Verify by running it, per the "verify the verification" rule:

1. In a scratch repo, write a feature spec, leave it untracked, run `/build`.
2. After the build, `git log --all -- features/<name>.md` must show both the add and the delete.
3. Negative control: revert the `build.md` change and repeat. Confirm the spec becomes unrecoverable — otherwise the fix is proving nothing.
4. For `/build-parallel`: confirm each worktree contains exactly one planned spec before fan-out.

## Open Questions

- **Should `/prd`, `/feature` and `/bug` commit their own files at creation time instead?** It would protect a spec that is written and then abandoned, or lost to an unrelated cleanup before any build runs. Rejected as the primary fix because those commands often run with `main` checked out, and committing there breaks "never commit directly to main." Committing in `/build` after the branch exists is convention-safe. The residual gap: a spec that is never built stays untracked — lower risk, since nothing auto-deletes it in that case.
- **Should `CLAUDE.md` be included in the spec commit?** Included above. It is written by `/prd` and amended by `/feature` and `/bug`, and on a fresh project it is untracked like the rest. It is not deleted by the cleanup step, so it is at less risk — but a worktree needs it, and `/build-parallel` already treats its presence as a precondition.
- **Squash or keep separate commits?** Plan keeps the spec commit, the build commits, and the removal commit distinct, matching `d5610d1` / `5b89229` / `8eea597`. If `/build` should instead squash, say so — but separate commits make the spec's content directly retrievable at a named sha.
