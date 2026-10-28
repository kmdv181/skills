#!/usr/bin/env sh
# Run every check for the lang plugin. Run from anywhere.
#
# First the bundle checks: every rule in rules/ is wired into hooks/hooks.json,
# and running each hook command prints that rule's payload. Then each rule's
# own test script.
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
fail=0
ok()  { echo "  ok   $1"; }
bad() { echo "  FAIL $1"; fail=1; }

echo "lang (bundle)"
if command -v jq >/dev/null 2>&1; then
  cmds=$(jq -r '.hooks.SessionStart[].hooks[].command' "$root/hooks/hooks.json")
  n_rules=0
  for rule in "$root"/rules/*.md; do
    name=$(basename "$rule" .md)
    n_rules=$((n_rules + 1))
    hit=0
    # Run each hook command the way the CLI does, and see whose payload it prints.
    while IFS= read -r cmd; do
      if CLAUDE_PLUGIN_ROOT="$root" sh -c "$cmd" 2>/dev/null | cmp -s - "$root/hooks/$name.json"
      then hit=$((hit + 1))
      fi
    done <<CMDS
$cmds
CMDS
    if [ "$hit" -eq 1 ]
    then ok "exactly one hook emits rules/$name.md"
    else bad "$hit hooks emit rules/$name.md, want 1"
    fi
  done
  n_cmds=$(printf '%s\n' "$cmds" | grep -c .)
  if [ "$n_cmds" -eq "$n_rules" ]
  then ok "$n_cmds hooks for $n_rules rules"
  else bad "$n_cmds hooks for $n_rules rules"
  fi
else
  echo "  skip hook wiring checks (jq not installed)"
fi

for t in "$root"/scripts/test-*.sh; do
  sh "$t" || fail=1
done

[ "$fail" -eq 0 ] || { echo "FAILED"; exit 1; }
echo "lang: all checks passed"
