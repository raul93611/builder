You are tidying CLAUDE.md memory files so they stay small enough to keep Claude fast. Every CLAUDE.md — the global `~/.claude/CLAUDE.md` and any project-local `CLAUDE.md` — is loaded into context at the **start of every session**. Its size is paid on every single request, and large always-on files measurably reduce recall and instruction-adherence.

## Why this matters

- CLAUDE.md is always-on context, not retrieved on demand — every character costs tokens on every request.
- Anthropic's published guideline: target **under 200 lines per file**. Longer files "consume more context and reduce adherence."
- Degradation is a gradient, not a cliff — there is no magic number — but a single memory file past ~40,000 characters is clearly doing more harm than good.

## Budget

For each CLAUDE.md file:
- **Target:** ≤ 200 lines / ~12,000 characters.
- **Ceiling:** ~40,000 characters. A file over this should be cut hard, not trimmed politely.

## Which file(s) to tidy

- **Default** (no argument): the `CLAUDE.md` in the current project root, if one exists.
- `global` or `--global`: the global `~/.claude/CLAUDE.md`.
- A path argument: that specific file.
- `all`: the global file plus every project `CLAUDE.md` you can find under the current directory (skip `node_modules`).

State which file(s) you are about to tidy before starting.

## Process

For each target file:

1. **Measure.** Report current line count and character count, and classify it: under target / over target / over ceiling.

2. **Dedup & merge.** Find entries that say the same thing or overlap heavily and merge them into one sharper, more general entry. In the global file the usual culprits are repeated framework lessons — e.g. several Prisma or NextAuth notes that collapse into one.

3. **Prune stale content.**
   - `## Known Bugs` entries marked `fixed` → remove (their history is in git).
   - Feature-inventory entries that are `built` → collapse to a single line, drop the detail.
   - Implementation notes describing code that now speaks for itself → remove.
   - A lesson superseded by a newer one → keep only the newer.

4. **Generalize lessons.** A project-specific lesson ("In project X, Prisma v7 broke the Docker build") becomes a reusable rule ("Prisma v7 isn't Docker-ready — use v5 for multi-stage builds"). Keep the `[YYYY-MM-DD]` prefix; drop the project specifics.

5. **Re-measure and report.** Show before/after line and character counts and the headroom left under target. If still over target, say so and list what else could be cut.

## Rules

- Never invent a lesson or change its meaning — only condense, merge, or remove.
- Preserve anything load-bearing: stack defaults, workflow conventions, active constraints, unfixed bugs, planned features.
- Show the user a short summary of what was merged and what was removed **before** saving — this file shapes every future session, so a wrong cut is expensive. If the user passed `--yes` or asked to run unattended, skip the confirmation but still print the summary.
- After saving, tell the user the new size and how much headroom remains under the 200-line / 12k-char target.
