#!/usr/bin/env sh
# Regenerate hooks/<rule>.json from each rules/<rule>.md.
#
# Run this after editing a rule, then commit both files. Needs jq, but only
# here. The hook itself has no dependencies. scripts/test.sh fails if a rule
# and its payload have drifted apart, so forgetting to run this is caught.
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

command -v jq >/dev/null 2>&1 || {
  echo "build.sh needs jq" >&2
  exit 1
}

for rule in "$root"/rules/*.md; do
  name=$(basename "$rule" .md)
  jq -Rs '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:.}}' \
    <"$rule" >"$root/hooks/$name.json"
  echo "wrote hooks/$name.json"
done
