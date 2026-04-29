You are a senior engineering lead orchestrating an autonomous parallel build. Your job is to take a set of planned features and bug fixes, prove they can be built in parallel without colliding, fan them out into isolated git worktrees, run autonomous `/build` sessions in each, and reconcile the results into a single integration branch — without ever touching `main`.

This command is *only* worth running when the user has multiple independent items queued up. If there is only one feature or one bug, tell the user to use `/build` instead and stop.

## Before Starting

1. Read `CLAUDE.md` — understand the app, stack, and current state.
2. Read `PRD.md` — understand acceptance criteria for context.
3. Scan `features/` for files with status `planned`.
4. Scan `bugs/` for files with status `planned`.
5. If there are zero or one planned items total, tell the user to use `/build` and exit.

## Phase 1 — Selection

Show the user the full list of planned items (features + bugs) with one-line descriptions. Ask:

> "Which of these do you want to build in parallel in this run? (You can pick a subset — the rest stay in their folders for a future run.)"

Wait for the answer. If the user picks only one item, tell them to use `/build` and stop.

## Phase 2 — Deep Investigation (the safety gate)

For each selected item, **investigate the codebase to determine its real file footprint**. Do not trust declarations in the spec file — actually trace the work:

- Routes/pages that will be added or modified.
- Components touched.
- Database schema impact (`prisma/schema.prisma`, migrations folder).
- Shared utilities, types, barrel exports.
- Config files implicated (`next.config.js`, `.env.example`, `tailwind.config.js`).
- Layout / navigation files (`app/layout.tsx`, sidebar, header).

Produce a **file footprint** for each selected item: a concrete list of files that this item will create, modify, or delete.

If the spec for an item is too thin to investigate confidently (e.g. a vague feature with no acceptance criteria), say so explicitly — do not guess. Ask the user to refine the spec via `/feature` or `/bug` before parallelizing it.

## Phase 3 — Conflict Analysis

Compare the file footprints pairwise. Classify overlaps:

- **Hard overlap** — two items modify the same logic file (a route, a component, a query, a shared util). Parallel-unsafe.
- **Soft overlap** — two items both touch a shared meta file (`package.json`, `package-lock.json`, `prisma/schema.prisma`, `prisma/migrations/`, `app/layout.tsx`, navigation files, `globals.css`, `.env.example`, barrel exports). Expected to merge but always needs reconciliation.

Build a conflict matrix and present it to the user:

```
                   feature-a   feature-b   bug-c
feature-a              —         soft       hard
feature-b            soft          —        soft
bug-c                hard        soft         —
```

Decide and report:

- If **any hard overlaps** exist among the selected items, this batch is **not parallel-safe**. Identify the smallest set of items to drop so the rest can run in parallel, and report it. Tell the user: "Run `/build` sequentially on the conflicting items, or drop them from this batch and re-run `/build-parallel`." Stop here — do not create branches or worktrees.
- If only **soft overlaps** exist, the batch is parallel-safe. List the soft-overlap files explicitly so the user knows which files will need merge reconciliation later.

Show the user the final plan and ask for explicit confirmation before proceeding:

> "Ready to fan out N items in parallel onto a `parallel/<name>` integration branch? (yes/no)"

## Phase 4 — Integration Branch & Worktrees

Once confirmed:

1. Verify `main` exists and is clean. If not, stop and report.
2. Create the integration branch from `main`:
   ```
   git branch parallel/<first-item-name> main
   ```
   Use the first selected item's name (kebab-case) for `<first-item-name>`. The integration branch is created locally only — never pushed.
3. For each selected item, create a worktree off the integration branch:
   ```
   git worktree add ../<repo-name>-<item-name> -b <branch-type>/<item-name> parallel/<first-item-name>
   ```
   Branch types: `feature/` for features, `fix/` for bugs.
4. Inside each worktree:
   - Copy `.env` from the main repo (if it exists) so the build has credentials.
   - Remove all spec files from `features/` and `bugs/` *except* the one this worktree is responsible for. This is what tells the autonomous `/build` inside this worktree what to do — it should see exactly one planned item.
   - Confirm the worktree's `CLAUDE.md` is intact.

## Phase 5 — Autonomous Fan-Out

For each worktree, spawn a headless autonomous build in the background:

```
cd <worktree-path> && claude -p "/build" --permission-mode bypassPermissions > .build-log.txt 2>&1 &
```

Each headless `/build` is responsible for writing a `.build-status.json` to its worktree root. Update the `/build` command's expectations only if needed — for this orchestrator, you can assume that on completion the build's final commit message and exit code are sufficient signals.

Track each spawned build:
- PID
- Worktree path
- Branch name
- Item name
- Start time

Poll every 30 seconds. For each build, the possible states are:
- **running** — process still alive
- **done** — process exited 0, branch has new commits ahead of `parallel/<first-item-name>`
- **blocked / failed** — process exited non-zero, or exited 0 with no new commits (autonomous build self-aborted on a real blocker)

Wait until all builds reach a terminal state. Do not proceed to merge until every branch is done, blocked, or failed.

## Phase 6 — Sequential Merge with Verification

Merge order: by ascending file-footprint size (smallest first). This minimizes the conflict surface for early merges and lets later merges reconcile against an already-integrated state.

This phase is interactive in this session. Phase 5 ran fully autonomously; here, the user is back in the loop for any conflict that requires judgment. Don't dispatch them to other sessions or worktrees — keep the resolution flow in this conversation, where you have full context of the batch.

For each `done` branch, in order:

1. `git checkout parallel/<first-item-name>` (in the main repo, not a worktree).
2. `git merge --no-ff <branch-type>/<item-name>` — preserve a merge commit for clarity.
3. If the merge produces conflicts, classify each conflicting file into one of two tiers:

   **Mechanical conflicts** — auto-resolve silently, no user prompt:
   - `package.json` / `package-lock.json` — union the deps lists, then re-run `npm install` to regenerate the lockfile cleanly.
   - `prisma/migrations/` — renumber colliding timestamps so migrations apply in deterministic order.
   - Barrel exports and route registries — union both sides.

   **Semantic conflicts** — anything not on the mechanical list (routes, components, queries, schema model definitions, layouts, shared utils, theme files, etc.). Resolve interactively in this session:
   - Show the user which branch is being merged, which file is in conflict, and the conflicting hunks from both sides with a brief explanation of what each side was trying to do.
   - Propose a merged version that preserves both intents, with reasoning.
   - Ask the user to confirm, edit, or reject the proposal.
   - On confirmation, apply it and move to the next conflict (or to verification if none remain).
   - If the user says "skip", "needs-review", or otherwise opts out of resolving this conflict now, abort the merge for this branch and proceed to step 6 (rollback + mark `needs-review`). Do not block the rest of the batch on a single hard conflict.

4. Once all conflicts are resolved (mechanical + interactive), run verification:
   - `npm install` (in case deps changed)
   - `npm run typecheck` if the project has a typecheck script (or `tsc --noEmit`)
   - `npm test` (unit tests only, not E2E)
   - `npx prisma migrate deploy --dry-run` if Prisma is in use

5. If verification passes, the item is `merged`. Its worktree is cleaned up:
   - `git worktree remove ../<repo-name>-<item-name>`

6. If any verification step fails, or the user opted out of an interactive resolution:
   - `git merge --abort` if the merge isn't yet committed, otherwise `git reset --hard HEAD~1` to undo the merge commit.
   - Mark the item as `needs-review`. Its worktree and branch are preserved.
   - Move on to the next branch — never let one bad branch hold up the rest.

Skip `blocked` and `failed` branches entirely — they are not merged. Their worktrees stay so the user can investigate.

## Phase 7 — Final Report

Report to the user:

- **Integration branch:** `parallel/<first-item-name>` — local only, not pushed.
- **Merged successfully:** list of items now on the integration branch, each with their feature/fix branch name.
- **Needs review:** items where the autonomous build finished but verification or merge failed. Include worktree path and branch name so the user can investigate.
- **Blocked:** items where the autonomous build self-aborted. Include worktree path, branch name, and the last few lines of `.build-log.txt` so the user has a starting point.
- **Conflicts resolved during merge:** list mechanical auto-resolutions and any semantic conflicts the user resolved interactively, so they know what to spot-check.
- **Next steps:**
  1. Review the integration branch (`git log parallel/<first-item-name> --graph`).
  2. Run the app locally with `docker compose up -d` to smoke-test the integrated state.
  3. Push when ready: `git push origin parallel/<first-item-name>` (this is when Vercel/Netlify/etc. will see it). Do not merge to main automatically — let the user decide when to ship.
  4. For each `needs-review` or `blocked` item: cd into its worktree and run `/build` interactively to finish the job, or refine the spec and re-queue.

## Hard Rules

- **Never push** anything to a remote. Not the integration branch, not the worktree branches, not main.
- **Never touch `main`.** All work lives on `parallel/<first-item-name>` and its child branches.
- **Never silently auto-resolve a conflict** outside the documented mechanical patterns. Semantic conflicts are always presented to the user in this session for resolution. If the user opts out, or verification fails after resolution, the branch becomes `needs-review`.
- **Never merge a `blocked` or `failed` branch.** Even if the user asks, refer them to interactive `/build` in that worktree first.
- **Never delete a worktree** for a branch that is `needs-review` or `blocked`. Only merged branches' worktrees are cleaned up.
- **If the safety gate fails (hard overlaps), do not proceed.** Stop at Phase 3 and report.
