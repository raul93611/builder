#!/usr/bin/env bash
# Guards /feature's source inventory.
#
# On 2026-09-30 a /feature run rebuilt a live page from a brief that said "write only from these
# facts". The agent read that as licence to delete a real primary source already on the page,
# because it was not on the list. Nobody was asked. /feature now inventories what an existing
# page cites, and offers keep / verify / remove for each link, before the first question.
#
# Structural only: this proves the prompt still SAYS it, never that a model obeys. The behaviour
# was checked once by running /feature headless in a scratch repo against a page carrying a
# source the brief did not list — redo that after any edit to Discovery.
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
fails=0
ok()   { printf '  ok    %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
line() { grep -n -- "$2" "$1" | head -1 | cut -d: -f1; }

check() {  # $1 = path to a feature.md; prints the checks, returns the number that failed
  local f="$1" before=$fails
  if grep -q 'inventory what it cites' "$f"; then
    ok "Discovery inventories what an existing page cites"
  else
    bad "Discovery has no source inventory"
  fi
  if grep -q 'unverified, not forbidden' "$f"; then
    ok "an unlisted source is unverified, not forbidden"
  else
    bad "nothing stops a closed list from removing a real source"
  fi
  if grep -q 'keep / verify / remove' "$f"; then
    ok "each link is put to the user as keep / verify / remove"
  else
    bad "the inventory is never put to the user"
  fi
  if grep -q 'Never skip step 6' "$f"; then
    ok "the trivial-change shortcut cannot skip the inventory"
  else
    bad "a 'trivial' rewrite skips the inventory"
  fi
  # Asked after the questions start, the decision is already made.
  local inv ask
  inv=$(line "$f" 'inventory what it cites')
  ask=$(line "$f" 'Ask ONE question at a time')
  if [ -n "$inv" ] && [ -n "$ask" ] && [ "$inv" -lt "$ask" ]; then
    ok "the inventory comes before the first question"
  else
    bad "the inventory does not precede the questions"
  fi
  return $(( fails - before ))
}

echo "structural — /feature inventories existing sources"
check "$REPO/commands/feature.md"

echo
echo "negative control — the same checks against /feature with step 6 removed"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
grep -v -e 'inventory what it cites' -e 'keep / verify / remove' -e 'Never skip step 6' \
  "$REPO/commands/feature.md" > "$TMP/feature.md"
saved=$fails
check "$TMP/feature.md" >/dev/null
caught=$(( fails - saved ))
fails=$saved
if [ "$caught" -gt 0 ]; then
  ok "negative control: $caught check(s) go red without the step"
else
  bad "negative control: every check passed without the step (test is vacuous)"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "PASS"
else
  echo "FAIL — $fails check(s) failed"
fi
exit $(( fails > 0 ? 1 : 0 ))
