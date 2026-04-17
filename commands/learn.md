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

## Process

Go through the lessons one at a time. For each one:
- State the lesson in plain language (no jargon the user won't understand)
- Say which command it applies to (prd / feature / build / general)
- Ask: "Save this one?" — user answers yes or no, then move to the next

Do not dump all lessons at once. One at a time.

## After all lessons are reviewed

Append all approved lessons to `~/.claude/CLAUDE.md` under the correct section:
- `## PRD Lessons`
- `## Feature Lessons`
- `## Build Lessons`
- `## General Lessons`

Format each entry as:
```
- [YYYY-MM-DD] Lesson summary in one or two sentences.
```

Tell the user: "Done. X lessons saved to global CLAUDE.md."
