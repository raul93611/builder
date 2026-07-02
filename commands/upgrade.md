You are a senior engineer performing a deliberate dependency upgrade. The stack pins nothing — it runs the latest stable of each package (see the global Default Stack) — so upgrades must be intentional and verified, never silent. Your job is to move dependencies forward safely and keep the build lessons in sync with what is actually installed.

## Scope
- This command is for **deliberate** upgrades — especially **major** version bumps, which need changelog reading and migration work.
- Continuous patch/minor churn is better handled by a bot (Renovate/Dependabot) or a plain `pnpm update`; don't reinvent that here. Spend your effort on the majors.

## Before Starting
1. Read `CLAUDE.md` (project) and the global Build Lessons — they map the known sharp edges of this stack's newer majors (e.g. Next.js `middleware.ts`→`proxy.ts`, Tailwind v4 base-ui vs Radix, NextAuth v5 `trustHost`). You will both *apply* these and *extend* them.
2. Confirm the working tree is clean and you are not on `main`.
3. Run `pnpm outdated` and group the results into patch / minor / major.

## Branch
- Create `chore/deps-upgrade` (or `chore/upgrade-<pkg>` for a single targeted major). Never commit to `main`.

## Process
1. **Report the plan** — show the user the outdated list, flagging the majors separately, before changing anything.
2. **Patch/minor first** — bump them together, run the full gate (below), commit: `chore: bump patch/minor deps`.
3. **Majors one at a time** — for each:
   - Read that release's migration guide / changelog for breaking changes.
   - Apply the known fixes already recorded in the Build Lessons for this major.
   - Make the code changes the upgrade requires.
   - Run the full gate.
   - Commit on its own: `chore: upgrade <pkg> to v<major>`.
4. **The gate** — must pass before every commit:
   - `pnpm build`, `pnpm typecheck`, `pnpm lint`, `pnpm test`
   - Then serve it: `pnpm db:start` + `pnpm serve`, and confirm the app actually boots and one core flow works. A green suite is not proof the app runs.
5. Keep `pnpm-lock.yaml` committed with each bump.

## Record What You Learned
- Any NEW breakage you hit and fixed that isn't already a lesson: add it to the global Build Lessons as a dated bullet — `[YYYY-MM-DD] <pkg> vN: <gotcha + fix>` — the same way `/learn` does. This is the whole point of the command: the lessons must never describe a version you are no longer on, nor omit one you now run.
- Keep `CLAUDE.md` lean; update any stack/version notes that changed.

## When Complete
- Open a PR from the branch (never push to `main`).
- Report to the user:
  - What was bumped — patch/minor as a group, then each major.
  - What code changed per major, and why.
  - Any new Build Lessons recorded.
  - Anything deferred — a major you chose not to take yet, and the reason (e.g. an ecosystem dep isn't ready).
