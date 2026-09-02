#!/usr/bin/env sh
# Behavioural checks for the hook payload and the rule text. Run from anywhere.
#
# These assert what the CLI actually consumes, the exact bytes on stdout, not
# that a schema validates. `claude plugin validate` says nothing about any of it.
# They also hold the rule to its own numbers: a rule about sentence length that
# ships a 40-word sentence has no credibility, with a reader or with a model.
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
payload="$root/hooks/session-start.json"
rule="$root/rules/simpler-english.md"
readme="$root/README.md"
measure="$root/scripts/measure.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# The limits the rule states. If the rule text changes its numbers, change
# these too; check 3 asserts the "30 words" phrase so the two cannot drift apart.
max_words=30
max_mean=20

fail=0
ok()   { echo "  ok   $1"; }
bad()  { echo "  FAIL $1"; fail=1; }

# within_limits <file> <label>: the prose obeys the sentence limits.
within_limits() {
  if "$measure" <"$1" | awk -v mw="$max_words" -v mm="$max_mean" \
       '$1=="max" && $2 > mw {exit 1} $1=="mean" && $2 > mm {exit 1} $1=="long" && $2 > 0 {exit 1}'
  then ok "$2 stays under $max_words words max, $max_mean mean"
  else bad "$2 breaks the sentence limits: $("$measure" <"$1" | grep -E '^(mean|max|long)' | tr '\n' ' ')"
  fi
}

# no_banned <file> <label>: no em dash, semicolon or Latin abbreviation, with
# quoted mentions allowed.
no_banned() {
  if "$measure" -q <"$1" | awk '($1=="dashes" || $1=="semicolons" || $1=="latin") && $2 > 0 {exit 1}'
  then ok "$2 uses no em dash, semicolon or Latin abbreviation"
  else bad "$2 uses a banned token: $("$measure" -q <"$1" | grep -E '^(dashes|semicolons|latin)' | tr '\n' ' ')"
  fi
}

echo "write-simpler-english"

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
  then ok "payload matches rules/simpler-english.md"
  else bad "payload is stale: run scripts/build.sh and commit both files"
  fi

  # 3. The rule the agent receives actually says the things it must say.
  text=$(jq -r '.hookSpecificOutput.additionalContext' "$payload")
  for phrase in "CEFR B2" "$max_words words" "technical terms"; do
    case "$text" in
      *"$phrase"*) ok "rule mentions: $phrase" ;;
      *)           bad "rule no longer mentions: $phrase" ;;
    esac
  done

  # 4. The repo-wide soft-wrap rule applies to this rule file too. Every prose
  #    line either stands alone or is followed by a blank, heading, or end of
  #    file. A line continued by another prose line is a wrap.
  if awk 'prev && $0 !~ /^($|#)/ { exit 1 } { prev = ($0 ~ /^($|#)/) ? 0 : 1 }' "$rule"
  then ok "rule text is soft-wrapped"
  else bad "rule text contains a hard-wrapped paragraph"
  fi

  # 4b. measure.sh is calibrated before it is trusted. Both fixtures are
  #     hardcoded and their expected numbers were counted by hand, so the check
  #     cannot follow the code it tests. The plain fixture must split into three;
  #     a splitter that never splits reports one sentence of 16 words.
  m=$(printf '%s\n' 'One two three four five six. Seven eight nine ten. Eleven twelve thirteen fourteen fifteen sixteen.' | "$measure")
  case "$m" in
    *"sentences 3"*"max 6"*"dashes 0"*"semicolons 0"*"latin 0"*) ok "measure.sh splits plain prose" ;;
    *) bad "measure.sh miscounts plain prose: $(echo "$m" | tr '\n' ' ')" ;;
  esac
  # A full stop inside bold still ends the sentence: two sentences of 3 words.
  m=$(printf '%s\n' 'This is **bold.** Next one here.' | "$measure")
  case "$m" in
    *"sentences 2"*"max 3"*) ok "measure.sh splits after emphasis markers" ;;
    *) bad "measure.sh merges across emphasis markers: $(echo "$m" | tr '\n' ' ')" ;;
  esac
  # 48 whitespace tokens, the two dashes included, in one sentence.
  m=$(printf '%s\n' 'The payload — which the hook emits at session start, e.g. on resume — is built ahead of time by the build script; the emit script is just a cat, so it cannot fail on a machine without jq, and there is no runtime escaping to get wrong.' | "$measure")
  case "$m" in
    *"sentences 1"*"max 48"*"dashes 2"*"semicolons 1"*"latin 1"*) ok "measure.sh flags dense prose" ;;
    *) bad "measure.sh misses dense prose: $(echo "$m" | tr '\n' ' ')" ;;
  esac

  # 4c, 4d. The rule obeys its own shape limits and uses none of the tokens it bans.
  within_limits "$rule" "rule text"
  no_banned "$rule" "rule text"

  # 4e. The README is the first text written under the rule, so it must pass it.
  within_limits "$readme" "README"
  no_banned "$readme" "README"
else
  echo "  skip jq-based checks (jq not installed)"
fi

# 5. emit-rule.sh reproduces the payload byte for byte.
if "$root/scripts/emit-rule.sh" | cmp -s - "$payload"
then ok "emit-rule.sh output matches the payload"
else bad "emit-rule.sh output differs from the payload"
fi

# 6. It runs with nothing on PATH but sh and cat, which is the point of
#    pre-encoding. Real copies, not symlinks, so the test cannot accidentally
#    reach the system PATH.
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
