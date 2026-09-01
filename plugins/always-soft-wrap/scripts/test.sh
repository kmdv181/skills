#!/usr/bin/env sh
# Behavioural checks for the hook payload. Run from anywhere.
#
# These assert what the CLI actually consumes — the exact bytes on stdout — not
# that a schema validates. `claude plugin validate` says nothing about any of it.
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
payload="$root/hooks/session-start.json"
rule="$root/rules/soft-wrap.md"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail=0
ok()   { echo "  ok   $1"; }
bad()  { echo "  FAIL $1"; fail=1; }

echo "always-soft-wrap"

# 1. The payload is the shape both Claude Code and Codex read.
if command -v jq >/dev/null 2>&1; then
  if jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' "$payload" >/dev/null 2>&1 &&
     jq -e '.hookSpecificOutput.additionalContext | type == "string" and length > 0' "$payload" >/dev/null 2>&1
  then ok "payload has hookSpecificOutput.additionalContext"
  else bad "payload shape is wrong"
  fi

  # 2. The payload still matches its markdown source.
  jq -Rs '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:.}}' <"$rule" >"$tmp/rebuilt.json"
  if jq -S . "$payload" >"$tmp/a" 2>/dev/null && jq -S . "$tmp/rebuilt.json" >"$tmp/b" && cmp -s "$tmp/a" "$tmp/b"
  then ok "payload matches rules/soft-wrap.md"
  else bad "payload is stale — run scripts/build.sh and commit both files"
  fi

  # 3. The rule the agent receives actually says the things it must say.
  text=$(jq -r '.hookSpecificOutput.additionalContext' "$payload")
  for phrase in "single line" "soft wrap" "fenced code"; do
    case "$text" in
      *"$phrase"*) ok "rule mentions: $phrase" ;;
      *)           bad "rule no longer mentions: $phrase" ;;
    esac
  done

  # 4. The rule practises what it preaches: no hard-wrapped paragraphs in the
  #    source. Every prose line either stands alone or is followed by a blank,
  #    heading, or end of file — a line continued by another prose line is a wrap.
  if awk 'prev && $0 !~ /^($|#)/ { exit 1 } { prev = ($0 ~ /^($|#)/) ? 0 : 1 }' "$rule"
  then ok "rule text is itself soft-wrapped"
  else bad "rule text contains a hard-wrapped paragraph"
  fi
else
  echo "  skip jq-based checks (jq not installed)"
fi

# 5. emit-rule.sh reproduces the payload byte for byte.
if "$root/scripts/emit-rule.sh" | cmp -s - "$payload"
then ok "emit-rule.sh output matches the payload"
else bad "emit-rule.sh output differs from the payload"
fi

# 6. It runs with nothing on PATH but sh and cat — the point of pre-encoding.
#    Real copies, not symlinks, so the test cannot accidentally reach the system PATH.
mkdir -p "$tmp/bin"
for b in sh cat dirname; do
  src=$(command -v "$b") && cp "$(readlink -f "$src")" "$tmp/bin/$b"
done
if [ ! -e "$tmp/bin/jq" ] && env -i PATH="$tmp/bin" "$tmp/bin/sh" "$root/scripts/emit-rule.sh" 2>/dev/null | cmp -s - "$payload"
then ok "runs on a PATH with no jq"
else bad "does not run without jq"
fi

# 7. A missing payload fails loudly instead of emitting nothing successfully.
cp -r "$root" "$tmp/copy"
rm -f "$tmp/copy/hooks/session-start.json"
if "$tmp/copy/scripts/emit-rule.sh" >/dev/null 2>&1
then bad "missing payload exited 0"
else ok "missing payload exits non-zero"
fi

[ "$fail" -eq 0 ] || { echo "FAILED"; exit 1; }
echo "all checks passed"
