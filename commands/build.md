---
description: "Autonomous build of the planned feature and bug specs, or the whole app from PRD.md on a first build"
---

You are a senior full-stack developer building autonomously from specs: planned features and bug fixes on an existing app or, on the first build, the whole app from `PRD.md`. You work independently, make decisions when things are ambiguous, and only stop if you hit a true blocker that cannot be resolved without user input.

**Which build is this?** Normally the app already exists and you build the `planned` specs in `features/` and `bugs/`. If there is no app yet (no `package.json`), this is the **first build**: you build the whole app from `PRD.md`, and every step marked *First build only* applies too.

Stack, scripts, local dev and deploy conventions are in the global `~/.claude/CLAUDE.md` (Default Stack, Local Dev, Workflow Conventions). Follow them unless the project's `CLAUDE.md` says otherwise; this command does not repeat them.

## Before Starting

1. Read `CLAUDE.md` — this is your technical context.
2. Read every file in `features/` and `bugs/` with status `planned` — these are the specs for this build. If none are planned and this is not a first build, stop and tell the user there is nothing to build.
3. Check the shelf: read every entry listed under "Shelf references" in the specs (and in `PRD.md` on a first build) with `read_shelf_entry`, then call `search_shelf` once per spec describing what it builds or fixes, and read anything new that applies. Treat entries as advice from past builds — the spec wins if they conflict. Skip silently if the shelf tools aren't available.
4. Verify each spec's blockers are resolved — credentials for any new external service it names. If any are missing, stop and tell the user what is needed before proceeding.
5. Ask the user (optional, one prompt only): "Do you have a Claude Design handoff for this build? Paste the full handoff snippet now, or press enter to skip."
   - **If skipped:** proceed normally — UI is built from the screen descriptions in the specs.
   - **If pasted:** treat the snippet as authoritative for visual design. Follow its instructions to fetch the linked bundle, read its README, and inspect the file referenced on the `Implement:` line. The Claude Design URL points to a bundle that exceeds the WebFetch size cap (~10 MB), so when WebFetch fails with a size error, fall back to `curl` via Bash to download the README and the implement-target file to a temp directory, then read them with the Read tool.
   - **Rule when a spec and the Claude Design handoff disagree on visual details:** the spec owns *what screens exist and what they do*; Claude Design owns *how they look*. Defer to the design bundle for layout, spacing, typography, and color application; defer to the spec for logic and flow.

**First build only:**
- Read `PRD.md` — this is your spec for the whole app. Do not deviate from it. If it is missing, stop and tell the user to run `/prd`.
- Verify the build blockers listed in `PRD.md` are resolved (API keys, credentials, etc). If any are missing, stop and tell the user what is needed.

## Git Setup

- Check if a `main` branch exists. If not, initialize it.
- Create a single branch for this build based on what is being done:
  - First build: `build/initial`
  - One or more features (with or without bugs): `feature/feature-name` (use the first feature's name)
  - Only bugs (no features): `fix/bugs-batch`
- All work happens on this branch. Never commit directly to main.

### Commit the specs before building anything

This build's last step deletes the specs it consumed. A file git has never seen exists in no
object at all — not in a commit, not as a dangling blob, not in the reflog — so deleting an
untracked spec destroys it and its Decisions log permanently, silently, with the build still
reporting success. Commit them first, every time.

As soon as the branch exists, stage the build's inputs **by explicit path** and commit:

```
git add PRD.md CLAUDE.md features/*.md bugs/*.md   # only the paths that actually exist
git commit -m "chore: track specs for this build"
```

- **Explicit paths only.** Never `git add -A`, `git add .`, or `git add features/` — blanket
  staging sweeps in whatever else happens to be sitting in the tree.
- **"Nothing to commit" is success, not an error.** The user may have committed the specs by
  hand. `git commit` exits non-zero with nothing staged — treat that as already done, carry on.
- **Fresh repo with no commits yet:** there is no root commit to branch from, so the order
  inverts. `git init`, stage the specs, commit them on `main` as `chore: add project specs`,
  *then* cut the build branch from it. A spec-only root commit is the project baseline rather
  than build work, so this does not break "never commit directly to main."

Do not start building until this commit exists.

## Build Process

Follow this order strictly.

### 1. First build only: Scaffold
- Set up the project exactly as the global Default Stack and Local Dev sections describe — structure, dependencies, Supabase CLI config with its own port range, Prisma schema, every standard `package.json` script, and `.env.example`.
- If `PRD.md` specifies seed data for dev, `db:seed` applies it (idempotent).

### 2. Fix Bugs First (if any)
- Fix every `planned` bug before touching features.
- A bug's acceptance criterion is its spec's expected behaviour. For each bug follow the TDD cycle:
  1. **Write a failing test** that follows the bug's steps to reproduce and asserts the expected behaviour.
  2. **Confirm it fails** in the way the bug describes.
  3. **Fix the code** until the test passes.
  4. **Commit** — fix code + test together: `fix: [bug name]`
- Update each bug file's status to `fixed` after the commit.

### 3. Build Features
- Work through features in the order of the `CLAUDE.md` feature inventory (first build: the order in `PRD.md`).
- A feature's tests come from the acceptance criteria in its spec — the feature file (first build: `PRD.md`). Every criterion gets at least one test, named after the criterion so a reviewer can trace one to the other; edge cases the spec lists get tests too. A criterion no unit test can prove (purely visual, a journey across screens) goes in the final report as something to check by hand.
- For each feature follow the TDD cycle strictly:
  1. **Write the unit tests first** — from those acceptance criteria. They must cover the core logic, expected outputs, and key edge cases.
  2. **Run the tests** — confirm they fail (Red). If one passes before any code is written, it is wrong — fix it.
  3. **Build the backend logic** — API routes, database queries, business logic — enough to make the tests pass.
  4. **Run the tests again** — confirm they pass (Green).
  5. **Build the UI + write component unit tests** — connect the frontend to the backend logic. Test that each component renders, reflects props, handles state changes, and fires event handlers correctly. Cover loading, error, and empty states.
  6. **Commit** — feature code + tests together: `feat: add [feature name]`
- Update each feature file's status to `built` after the commit.
- Unit tests cover: API routes, data queries, validations, business logic, data transformations, UI components (render, props, state, handlers, conditional states).
- E2E coverage (full user journeys across screens) is added later by `/test` when needed — not all projects run it, so unit coverage on UI components must stand on its own.

### 4. UI Standards

If a Claude Design handoff was provided in step 5 of Before Starting, it takes precedence over the specs and the defaults below for **visual** decisions — component layout, spacing, typography, color application, micro-interactions. Use the rules below as fallbacks for anything the design bundle does not specify.

- Build the UI changes each spec describes, inside the app's existing navigation.
- **First build only:** build the screen inventory and navigation structure from `PRD.md`, and apply its brand colors to the shadcn theme (CSS variables in `globals.css`).
- Component architecture — compose, don't duplicate:
  - shadcn/ui `components/ui/*` are your primitives — never rebuild a Button/Input/Dialog it ships.
  - Build app-specific reusable components (`<PageHeader>`, `<StatTile>`, `<UserCard>`) once in `components/` from those primitives; reuse across screens.
  - A component used by only one feature stays colocated with that feature.
  - Pages and layouts live in the App Router (`app/**`) — no parallel page system.
  - Before building a screen, reuse or extract an existing shared component; if you write the same markup twice, lift it into one.
- UI polish requirements — every screen must have:
  - Subtle shadows and rounded corners on cards and panels
  - Hover and focus states on all interactive elements
  - Consistent spacing using Tailwind spacing scale
  - Loading skeletons for async data (not spinners)
  - Smooth transitions on state changes (150-200ms)
  - Empty states with a helpful message and a call to action
  - Mobile responsive layout
- Testable markup — so Playwright (and unit tests) can locate elements without brittle selectors:
  - Real semantic elements: `<button>`, `<a>`, `<form>`, `<label htmlFor>` paired with `<input id>`
  - `data-testid` on anything not naturally addressable: cards, list rows, modals, status badges, toasts
  - List items uniquely addressable — `data-testid` includes the row's id, or each item has distinct visible text

### 5. Environment & Configuration
- Never hardcode secrets or API keys. Every new env variable goes in `.env.example`, documented.

## Commit Strategy
- Commit after each completed feature: `feat: add [feature name]`
- Commit after each fixed bug: `fix: [bug name]`
- Commit schema changes separately: `chore: update database schema`
- Commit config changes separately: `chore: setup [tool/service]`
- Write clear, descriptive commit messages

## Simplify Pass

After every bug and feature is built and committed, run `/simplify` (the `simplify` skill) over this branch's diff against `main`. It reviews for reuse, simplification and efficiency and applies the fixes itself. Tell it to leave alone: the standard scaffold (scripts, Supabase config, seed, `.env.example`), the UI Standards above, validation at trust boundaries, error handling, security, accessibility, the tests, and anything a spec requires.

Then run the full test suite **once**. If anything fails, fix it and re-run only the failed tests — not the whole suite. Commit the result on its own: `refactor: simplify [area]`. If `/simplify` changed nothing, note it in one line and move on.

## When Build is Complete

1. Update `CLAUDE.md` — and keep it lean. It loads into context at the start of every future session, so its size costs performance on every request. Target **under ~200 lines / ~12k characters**.
   - Fill in or update the project structure — a concise tree, not an exhaustive file listing.
   - Update feature inventory — mark all built features as `built`, one line each, no essay.
   - Add only implementation notes that aren't obvious from the code: non-obvious decisions, gotchas, active constraints. Skip anything a developer would learn just by reading the file it describes.
   - If `CLAUDE.md` is already over target when you open it (common on long-running projects), consolidate it back under target as part of this step — merge stale notes, drop detail for code that now speaks for itself — or run `/tidy` first. Never leave it bigger than you found it without a reason.

2. `DEPLOYMENT.md` — **First build only:** generate it with production setup instructions: environment variables (reference `.env.example`, including the pooler split from the global Local Dev section), database migrations against Supabase (`prisma migrate deploy`) and seeding if applicable, any third-party services to configure in prod, and a health check URL. Otherwise update it only if this build added an env variable, a service, or a deploy step.

3. Clean up spec files — they have been consumed and their content is now in `CLAUDE.md`:
   - Delete `PRD.md` (first build only)
   - Delete all files inside `features/` that have status `built`
   - Delete all files inside `bugs/` that have status `fixed`
   - **Commit the deletion** — `chore: remove consumed specs`. Their content stays retrievable at
     the spec commit from Git Setup, so this is a clean removal rather than a loss; leaving it
     uncommitted just hands the user a dirty tree to reconcile.
   - **If the Git Setup spec commit never happened, do not delete anything.** Say so in the final
     report and leave the files in place. An uncommitted spec is unrecoverable once deleted, and a
     tidy folder is not worth destroying the record of every decision behind the work.

4. Do NOT push to main. Leave the branch ready for review.

5. Report to the user:
   - What was built and fixed
   - Any decisions made that were not in the specs
   - Any items that were skipped or partially implemented and why
   - Acceptance criteria no unit test covers, and how to check each by hand
   - What `/simplify` changed, or "nothing"
   - Next steps (review branch, start Supabase with `pnpm db:start`, run locally with `pnpm serve`, push when ready)

## Decision Making Rules

When a spec is ambiguous on something minor:
- Make the most sensible decision
- Note it in the final report

When something is completely missing from the specs and it blocks progress:
- Stop
- Tell the user exactly what information is needed
- Do not guess on things that affect data model or core user flows
