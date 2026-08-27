#!/usr/bin/env bash
# Guards bugs/build-consumes-uncommitted-specs.md.
#
# /build deletes the spec files it consumes. A file git has never seen exists in no object at
# all, so deleting an untracked spec destroys it permanently. This checks two things: that the
# commands still *say* to commit specs first, and that the git recipe they prescribe actually
# works — including a negative control proving the check can fail.
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
fails=0
ok()   { printf '  ok    %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
line() { grep -n -- "$2" "$1" | head -1 | cut -d: -f1; }

echo "structural — the commands instruct committing specs"

if grep -q 'chore: track specs for this build' "$REPO/commands/build.md"; then
  ok "build.md commits specs during Git Setup"
else
  bad "build.md never commits specs before building"
fi

if grep -q 'chore: remove consumed specs' "$REPO/commands/build.md"; then
  ok "build.md commits the cleanup deletion"
else
  bad "build.md deletes consumed specs without committing the deletion"
fi

# The commit is worthless if it lands after the destructive step.
track=$(line "$REPO/commands/build.md" 'chore: track specs for this build')
clean=$(line "$REPO/commands/build.md" 'Delete `PRD.md`')
if [ -n "$track" ] && [ -n "$clean" ] && [ "$track" -lt "$clean" ]; then
  ok "spec commit is ordered before the cleanup step"
else
  bad "spec commit does not precede the cleanup step"
fi

if grep -q 'chore: track specs for this parallel build' "$REPO/commands/build-parallel.md"; then
  ok "build-parallel.md commits specs before fan-out"
else
  bad "build-parallel.md creates worktrees from uncommitted specs"
fi

ptrack=$(line "$REPO/commands/build-parallel.md" 'chore: track specs for this parallel build')
ptree=$(line "$REPO/commands/build-parallel.md" 'git worktree add')
if [ -n "$ptrack" ] && [ -n "$ptree" ] && [ "$ptrack" -lt "$ptree" ]; then
  ok "spec commit is ordered before 'git worktree add'"
else
  bad "spec commit does not precede worktree creation"
fi

echo
echo "behavioural — the prescribed git recipe survives the delete"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
seed() {  # $1 = dir; makes a repo with an untracked spec on a build branch
  git init -q -b main "$1"
  git -C "$1" config user.email t@example.com
  git -C "$1" config user.name  tester
  git -C "$1" commit -q --allow-empty -m "root"
  git -C "$1" checkout -q -b fix/bugs-batch
  mkdir -p "$1/features"
  printf 'Status: planned\nDecisions: chose in-app banner over email.\n' > "$1/features/thing.md"
}
recoverable() { git -C "$1" log --all --format=%H -- features/thing.md | grep -q .; }

# Negative control. Without the commit the spec must be UNRECOVERABLE — if this ever reports
# recoverable, the checks below prove nothing and should be deleted rather than trusted.
d="$TMP/control"; seed "$d"
rm "$d/features/thing.md"
if recoverable "$d"; then
  bad "negative control: deleted spec was recoverable without a commit (test is vacuous)"
else
  ok "negative control: uncommitted spec is unrecoverable once deleted"
fi

# The fix. Explicit-path staging, then delete — content must still be in history.
d="$TMP/fixed"; seed "$d"
git -C "$d" add features/thing.md
git -C "$d" commit -q -m "chore: track specs for this build"
rm "$d/features/thing.md"
if recoverable "$d" && git -C "$d" show "fix/bugs-batch:features/thing.md" 2>/dev/null | grep -q 'in-app banner'; then
  ok "committed spec survives deletion, Decisions log intact"
else
  bad "committed spec did not survive deletion"
fi

# Re-running the recipe on already-tracked specs must be a harmless no-op, not an abort.
before=$(git -C "$d" rev-parse HEAD)
git -C "$d" checkout -q -- features/thing.md
git -C "$d" add features/thing.md
git -C "$d" commit -q -m "chore: track specs for this build" >/dev/null 2>&1
if [ "$(git -C "$d" rev-parse HEAD)" = "$before" ]; then
  ok "already-tracked specs are a clean no-op"
else
  bad "re-running the spec commit created a spurious commit"
fi

# Fresh repo: no root commit to branch from, so specs commit on main first.
d="$TMP/fresh"; git init -q -b main "$d"
git -C "$d" config user.email t@example.com
git -C "$d" config user.name  tester
mkdir -p "$d/features"
printf 'Status: planned\n' > "$d/features/thing.md"
git -C "$d" add features/thing.md
git -C "$d" commit -q -m "chore: add project specs"
if git -C "$d" checkout -q -b build/initial main 2>/dev/null && recoverable "$d"; then
  ok "fresh repo: specs root-commit on main, branch cuts from it"
else
  bad "fresh repo ordering failed"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "PASS"
else
  echo "FAIL — $fails check(s) failed"
fi
exit $(( fails > 0 ? 1 : 0 ))
