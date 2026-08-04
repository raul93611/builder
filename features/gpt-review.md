# /gpt — GPT second opinion on the current diff

Runs OpenAI's Codex CLI read-only over the current diff, triages every finding against the real code, and offers to file the confirmed ones as bugs.

**Status:** `built`

## Why

Command's Builder is Claude-only. Adding GPT as a second *coder* would mean maintaining a parallel event parser, session store and auth forever. Using it as a read-only *reviewer* costs none of that and buys the thing Claude cannot give itself: a decorrelated second opinion on its own work.

This command is the zero-code trial of that idea. If the findings prove useful it gets built into Command properly as a button/endpoint. Tracked as command-dev ticket #355.

## Deliverable

One new file: `commands/gpt.md`. No code anywhere.

Match the house style in `commands/` — no frontmatter, opens with "You are a …", plain prose instructions. Target 70–90 lines; `bug.md` is 71 and `learn.md` is 53. The spec below carries a lot of mechanical detail, and the command must not turn into a man page. Put the invocation in one fenced block and keep everything else in the house voice.

## User flow

1. **Invoke.** `/gpt` with no argument reviews uncommitted work. `/gpt <branch-or-sha>` reviews against a base branch or a single commit — resolve which via git rather than guessing from the string.
2. **Preflight.** Check `codex` is on PATH and `codex login status` reports logged in. If either fails, stop with a clear message naming what's missing. Do not attempt to authenticate.
3. **Make untracked files visible.** If the scope is uncommitted and there are untracked files, `git add -N .` so their content appears in `git diff`, and restore the index afterwards — including when the review fails. Never `git add -A`.
4. **Run the review**, capturing the report to a `mktemp` file.
5. **Relativize paths.** Codex emits absolute paths; rewrite them against the repo root before showing the user anything.
6. **Triage every finding against the actual code.** This is the point of the command being a slash command rather than a shell alias. Codex cannot run tests or execute anything, so it will occasionally be confidently wrong. Read the code and reach one of three verdicts:
   - **Confirmed** — the failure is real. Say what breaks.
   - **Refuted** — must cite the specific line or behaviour that disproves it. A refutation without evidence is not a refutation.
   - **Unverified** — depends on runtime behaviour, production data, or something otherwise uncheckable. Say what would settle it.

   Claude is grading code Claude wrote. The findings most likely to be wrongly refuted are exactly the ones from Claude's own blind spot, which is what the whole command exists to catch — so default to `unverified` over `refuted` when the evidence isn't there.
7. **Report** grouped by severity, with every finding's verdict marked. Refuted findings are reported too, with the reason — a false positive is signal about whether this approach is worth building into Command.
8. **Offer to file the confirmed findings**, one at a time, the way `/learn` walks lessons. For each: show it, ask whether to file it, move on. Approved ones are written to `bugs/` in the format `/bug` produces, so `/build` picks them up on the next run. Unverified and refuted findings are never offered.
9. **Never auto-apply a fix.** The user decides what to act on.

## Environment (already set up — do not re-derive)

- `codex-cli 0.145.0` at `~/.local/bin/codex`, authenticated via ChatGPT.
- Default model `gpt-5.6-sol`, default reasoning effort `none`.
- `bubblewrap` is not installed, so Codex falls back to a bundled copy and warns on stderr. Harmless. `apt install bubblewrap` would silence it.

## Verified facts about `codex exec review`

Confirmed by running it and by `codex exec review --help`. These override the docs.

- **No `--sandbox` flag** — it already defaults to `sandbox: read-only`. Passing one errors out.
- **No `-C`/`--cd` flag** — set the working directory by running from the target repo.
- **`--uncommitted`, `--base <branch>` and `--commit <sha>` are mutually exclusive with a custom PROMPT.** Git-aware scoping or your own instructions, never both. Use the scoping flags.
- **It reads `CLAUDE.md` unprompted** — it cited a repo's tenant-scoping convention by name without being told the file existed. No `AGENTS.md`, no "read the conventions first" preamble.
- **The report prints to stdout twice.** Always read the `-o` file; never parse stdout.
- **stderr carries the entire event log**, not just errors. Judge success on exit code plus a non-empty output file — never on stderr being non-empty.
- **Always pass `--ephemeral`** so no session files are written. This is what keeps Codex from becoming a resident of the project: nothing to clean up, no second memory to drift from Claude's.

Known-good invocation:

```bash
cd <target repo>
codex exec review --uncommitted --ephemeral -o "$REPORT" < /dev/null
```

`< /dev/null` matters — without it Codex reads stdin and logs "Reading additional input from stdin".

Output format, severities `P1` and `P2` observed:

```
- [P1] <short title> — /absolute/path/to/file.ts:19-20
  <paragraph explaining the failure and its consequence>
```

## Data model changes

None. The only files written are `bugs/*.md` entries the user explicitly approves.

## External dependencies

Codex CLI and a logged-in ChatGPT account. Both already in place; no credentials to obtain. The command should state once, plainly, that running it sends the diff — and any file Codex opens — to OpenAI. Cheap to say now, and it matters the first time this runs on a client repo.

## Acceptance criteria

Craig tests this manually; no acceptance run is part of the build.

- Preflight fails clearly and does nothing else when `codex` is absent or logged out.
- A review of brand-new, never-committed files returns findings, and the index is left exactly as it was found — including when the review errors partway.
- Reported paths are repo-relative.
- Every finding carries a verdict, and refutations cite evidence.
- No bug file is written without an explicit yes.
- No fix is ever applied automatically.
- A run against the planted-bug repo (loop with `i <= items.length`; a query missing `where: { userId }`; a mutation taking no user identifier; an `async` callback passed to `.forEach`) finds all four, and does not flag the correct control function alongside them.

## Out of scope

- Auto-fixing anything.
- Any change in the `command-dev` repo — that comes after this trial.
- MCP server, REST endpoint, UI.
- A run log or scorecard.
- Reviewing anything other than a git diff.

## Decisions

- **Command named `/gpt`, not `/review`** — Claude Code already ships `/review`, `/code-review` and `/security-review`, and `install.sh` symlinks `commands/` straight onto `~/.claude/commands`, so the name would land next to the built-ins. Resolution order aside, three review-something commands meaning three different things is bad either way. The distinguishing feature here is *who* reviews, so the name says that.
- **Findings go to chat and to `bugs/`** — chose over chat-only so `/build` picks the confirmed ones up without anything being retyped.
- **One-at-a-time approval before each bug file** — chose over auto-writing P1s. Matches `/learn`, keeps "the user decides what to act on" literally true, and the yes/no on each finding is itself the signal this trial is meant to produce.
- **No run log** — chose over a global log in `~/.claude/`. Keeps the zero-footprint promise intact. The cost is real and accepted: whether this is worth building into Command stays a judgement call rather than a tally.
- **A third `unverified` verdict, reported but never filed** — keeps `bugs/` factual while stopping a real risk from vanishing into a false refutation.
- **`git add -N .` and restore, never `git add -A`** — verified that `-N` surfaces full untracked content in `git diff` and `git reset` reverses it cleanly with nothing staged. `git add -A` is the directory-wide add the global General Lessons already warn about sweeping in files that aren't yours.
- **`mktemp` for the report, not a fixed path** — a failed run would otherwise leave a stale report to be parsed as fresh on the next invocation.
- **Testing left to Craig** — no acceptance run performed as part of the build.
- **No `CLAUDE.md` inventory entry** — this repo has no `CLAUDE.md`, and shouldn't grow one solely to hold a feature list.
