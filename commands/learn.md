---
description: "Pull reusable lessons and approaches from this build into the global CLAUDE.md and the shelf, one at a time"
---

You are reviewing the current build session to extract lessons worth saving globally for future projects.

## How it works

1. If this is the same conversation where `/build` was run, you already have full context — use it directly.
2. If this is a fresh conversation, read `CLAUDE.md` and the git log to reconstruct what happened during the build.

## What to look for

Identify decisions, issues, and solutions that:
- Would apply to future projects, not just this one
- Were non-obvious or required trial and error to resolve
- Would save significant time if known upfront

Ignore anything that is specific to this app's business logic or data model.

Good candidates:
- Dependency version conflicts and how they were resolved
- Framework gotchas and workarounds
- Docker, CI, or deployment issues and their fixes
- Patterns that worked unexpectedly well

Also look for **approaches**: how a feature was built that a future project could reuse — the shape of the solution and why it worked, not this app's business logic.

## Where each lesson goes

- **Global CLAUDE.md** — a high-level rule that should shape every session, in one or two sentences.
- **Shelf** — the detailed version: the situation, what we did, why, when it applies. Every approach goes here.
- **Both** — a one-line rule in CLAUDE.md plus the detailed shelf entry.

If the shelf tools aren't available in this session, save lessons to CLAUDE.md only and skip approaches — they're too detailed for the global file. Tell the user which ones were skipped.

## Process

Go through the lessons one at a time. For each one:
- State it in plain language and say which command it applies to (prd / feature / build / general).
- Propose a destination (CLAUDE.md / shelf / both) with one line of why.
- For the shelf, show the drafted entry (template below).
- Ask: "Save this one?" — the user can say yes, no, or change the destination.

Do not dump all lessons at once. One at a time.

## Shelf entry template

Fields: title · kind (`lesson` or `approach`) · one-line summary · learned in (this project) · tags — lowercase; call `list_shelf_tags` first and reuse existing tags.

Body — these headings, in this order:
- `## Situation` — what we were building or what went wrong
- `## What we did` — the fix or the approach
- `## Why it works` — reasoning and trade-offs
- `## When it applies` — and when it doesn't; write it the way a future build would describe its own problem
- `## Watch out for` — optional

No code blocks — inline names of commands, settings and packages only. About 400 words max.

## Saving to the shelf

Save each shelf entry right after the user says yes, before moving to the next lesson — a refusal below may need their decision, so settle it while that lesson is still in front of them. CLAUDE.md lessons still wait until all lessons are reviewed.

Call `save_shelf_entry`. If it refuses:
- **Close match found:** show the user the match. Recommend updating it with `update_shelf_entry` — add what's new, a one-line reason, and `also_seen_in` this project. If it really is different, save again with `distinct: true`. The user decides.
- **Template broken:** fix the entry to the rule named in the refusal and retry. Only ask the user if the fix would change the meaning.

## After all lessons are reviewed

Save approved lessons whose destination is CLAUDE.md or both to `~/.claude/CLAUDE.md` under the correct section:
- `## PRD Lessons`
- `## Feature Lessons`
- `## Build Lessons`
- `## General Lessons`

Format each entry as:
```
- [YYYY-MM-DD] Lesson summary in one or two sentences.
```

For a lesson that went to both, end the bullet with its shelf entry's id — e.g. `(shelf #12)` — so every session knows the detail exists and where to find it. Keep the id when merging or replacing an entry.

**Keep the global file lean — it loads into context at the start of every session, in every project, so its size costs performance on every request.** Do not blindly append:

1. **Dedup / supersede before saving.** For each approved lesson, scan the target section first:
   - If a near-duplicate already exists, merge the two into one entry that keeps every detail of both, instead of adding a second.
   - If the new lesson supersedes an old one (newer framework version, better fix), replace the old entry rather than stacking both.
   - Only add a fresh bullet when the lesson is genuinely new.
2. **Watch the budget.** Target the whole file at **under 200 lines**. If saving these lessons would push it past that, run `/tidy global` first. Making room may delete, merge or move a lesson, but never reword one to save space.

Tell the user: "Done. X lessons saved to global CLAUDE.md (now N lines), Y added to the shelf, Z shelf entries updated."
