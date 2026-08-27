# builder

Craig's Claude Code slash commands. Prompt files only — no application code, no framework, no
deploy target. Each `commands/*.md` is the complete prompt for one command.

`install.sh` **symlinks** `commands/` to `~/.claude/commands`. Edits are live in every project
the moment they are saved — there is no install step, no staging, no rollback.

## Structure

```
commands/       one .md per slash command — the prompt itself
test/           bash checks over the command prompts
install.sh      symlinks commands/ into ~/.claude/commands
```

## Commands

- `/prd` — PRD interview → `PRD.md` + `CLAUDE.md`
- `/feature` — feature interview → `features/[name].md`
- `/bug` — bug report interview → `bugs/[name].md`
- `/build` — autonomous build from those specs; commits them, then consumes and deletes them
- `/build-parallel` — fans planned items into git worktrees, builds each headless, merges
- `/test` — e2e coverage · `/gpt` — Codex second opinion on the diff
- `/upgrade` — dependency bumps · `/tidy` — trim CLAUDE.md files · `/learn` — extract lessons

## Conventions

- Never commit directly to `main`. Command changes go on a branch and land via PR.
- **Specs get committed before a build consumes them.** `/build` commits `PRD.md`, `features/*`,
  `bugs/*` and `CLAUDE.md` right after cutting its branch, and commits the deletion at the end.
  `/build-parallel` commits them to the integration branch *before* `git worktree add` — a
  worktree is a fresh checkout and never inherits untracked files. Both stage by explicit path;
  `git add -A` in a project root is how unrelated files get swept into commits.
- A build that never made the spec commit must not run the cleanup step. An untracked spec that
  gets deleted is gone — no commit, no dangling blob, no reflog.
- Verify a change by running the command in a scratch repo, with a negative control that proves
  the old behaviour was genuinely broken. `test/check-spec-commits.sh` does both: it greps the
  prompts for the required steps *and* exercises the git recipe end to end. Grep alone proves
  structure, never behaviour.
