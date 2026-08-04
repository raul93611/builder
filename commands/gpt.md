You are a senior engineer getting a second opinion on the current work from a different model. OpenAI's Codex CLI reviews the diff read-only, and you triage what it finds against the actual code before the user sees any of it. Codex cannot run tests or execute anything, so it will occasionally be confidently wrong — separating the real findings from those is the job, and it is the whole reason this is a command and not a shell alias.

Running this sends the diff, and any file Codex opens while reviewing, to OpenAI. Say so before the first run in a repo that isn't obviously the user's own.

## Before Starting

1. Confirm `codex` is on PATH and that `codex login status` reports logged in. If either fails, stop and say which one — do not try to authenticate.
2. Confirm you are in a git repo and there is something in scope to review.

## Scope

- **Default** (no argument): uncommitted work — staged, unstaged and untracked.
- **An argument**: resolve it with git. A branch becomes `--base <branch>`; a commit sha becomes `--commit <sha>`. If it resolves to neither, stop and say so rather than guessing.

Untracked files are invisible to `git diff`. When the scope is uncommitted and `git status --porcelain` shows any `??` entries, run `git add -N .` first so their contents reach the reviewer, and restore with `git reset` once the review finishes — including when it fails partway. Never `git add -A`: it stages content and sweeps in files that aren't yours.

## Run the Review

Capture the report to a fresh temp file. Codex prints the report to stdout twice — read the file, never stdout.

```bash
REPORT=$(mktemp)
codex exec review --uncommitted --ephemeral -o "$REPORT" < /dev/null
```

Swap `--uncommitted` for `--base <branch>` or `--commit <sha>` as the scope requires — exactly one of the three. `< /dev/null` stops Codex reading stdin. `--ephemeral` leaves no session files behind, which is what keeps this from becoming a resident of the project. There is no `--sandbox` flag (it is already read-only) and no `-C` flag (cd to the repo instead).

Allow several minutes on a large diff. Judge the outcome on the exit code plus a non-empty report file — never on stderr, which carries the entire event log and a harmless warning about missing bubblewrap.

Findings come back as a summary paragraph followed by entries like:

```
- [P1] <short title> — /absolute/path/to/file.ts:19-20
  <paragraph explaining the failure and its consequence>
```

Paths are absolute. Rewrite every one relative to the repo root before showing the user anything.

## Triage

**Read the code behind every finding before reporting it.** Reach one of three verdicts:

- **Confirmed** — the failure is real. State what breaks and when.
- **Refuted** — cite the specific line or behaviour that disproves it. A refutation without evidence is not a refutation.
- **Unverified** — it turns on runtime behaviour, production data, or something else you cannot check by reading. Say what would settle it.

You are grading code you wrote. The findings most likely to be wrongly refuted are exactly the ones from your own blind spot — which is the thing this command exists to catch. When the evidence for a refutation isn't there, the verdict is unverified, not refuted.

## Report

Group by severity, and mark every finding with its verdict. Report the refuted ones too, with the reason: a false positive says as much about whether this approach is worth keeping as a real catch does.

## File the Confirmed Findings

Go through the confirmed findings **one at a time**. Show the finding, ask "File this one?", wait for yes or no, then move to the next. Do not list them all and ask once.

For each yes, write a file to `bugs/` using the same shape `/bug` produces — `bugs/[short-kebab-name].md` containing:

- Name and one-line description
- Status: `planned`
- Severity, taken from the finding's P-level
- The failure the reviewer described, and what triggers it
- **Investigation** — what you confirmed it against, with file and line references
- **Fix Plan** — proposed steps and files to touch

Skip steps-to-reproduce when the finding is static rather than a runtime bug. If the project has a `CLAUDE.md` with a `## Known Bugs` section, add the one-line entry there the way `/bug` does.

Never offer a refuted or unverified finding for filing. If a finding is unverified and looks serious, say so in the report and let the user decide — do not quietly promote it.

## Never

- **Apply a fix.** The user decides what to act on; this command only reports and files.
- **Write a bug file without an explicit yes.**
- **Leave the index changed** by the untracked-file workaround.

## When Complete

Tell the user how many findings came back and how they split across confirmed / refuted / unverified, and name any bug files written. If nothing was filed, say that plainly — a clean review is a result, not a failure.
