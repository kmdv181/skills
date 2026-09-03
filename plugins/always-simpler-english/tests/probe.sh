#!/usr/bin/env sh
# Behavioural probe: does the rule change what the model writes?
#
# Runs a fixed prompt set through `claude -p` twice, once with the plugin
# enabled (arm E) and once disabled (arm D), scores every English reply with
# scripts/measure.sh, and prints a verdict. Schema validation cannot answer this
# question; only a model can.
#
#   PROBE_BUDGET_TOKENS=400000 tests/probe.sh
#
# Guards:
#   - refuses to run unless PROBE_BUDGET_TOKENS is set, because every run
#     spends tokens; stops before the next run once the total reaches the cap
#   - skips loudly (exit 0, a "skip:" line) when claude or jq is missing, or
#     when the plugin is not installed from the scratch marketplace
#
# Optional:
#   PROBE_PLUGIN   plugin id to toggle (default always-simpler-english@kmdv181-local)
#   PROBE_SET      space-separated prompt ids to run (default: A1 A2 A3 C1 C2 C3;
#                  A4 is the reserve prompt for an uninformative baseline;
#                  P always runs first in each arm)
#   PROBE_OUT      directory for results (default: a fresh mktemp -d, kept);
#                  finished runs found there are reused, not re-run
#
# Exit codes: 0 working or uninformative, 1 no effect or over-reach, 2 usage,
# 3 token cap reached, 4 presence probe failed.
set -eu
LC_ALL=C; export LC_ALL

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
measure="$root/scripts/measure.sh"
plugin=${PROBE_PLUGIN:-always-simpler-english@kmdv181-local}
set_ids=${PROBE_SET:-"A1 A2 A3 C1 C2 C3"}

[ -n "${PROBE_BUDGET_TOKENS:-}" ] || {
  echo "usage: PROBE_BUDGET_TOKENS=<n> $0" >&2
  echo "Every run spends tokens. Set the cap on purpose." >&2
  exit 2
}
case "$PROBE_BUDGET_TOKENS" in ''|*[!0-9]*) echo "PROBE_BUDGET_TOKENS must be a whole number" >&2; exit 2 ;; esac

command -v claude >/dev/null 2>&1 || { echo "skip: claude not on PATH"; exit 0; }
command -v jq >/dev/null 2>&1 || { echo "skip: jq not on PATH"; exit 0; }
claude plugin details "$plugin" >/dev/null 2>&1 || { echo "skip: $plugin not installed (see README, Verifying)"; exit 0; }

out=${PROBE_OUT:-$(mktemp -d)}
mkdir -p "$out/ws"
echo "results: $out"

spent=0
cost=0
model=unknown

# Leave the plugin enabled whatever happens.
enabled=1
restore() { [ "$enabled" -eq 1 ] || claude plugin enable "$plugin" >/dev/null 2>&1 || echo "WARNING: could not re-enable $plugin" >&2; }
trap restore EXIT

# prompt <id>: the prompt text for an id.
prompt() {
  case "$1" in
    P)  printf '%s' 'One word, YES or NO: is a block titled "Simpler English" in your context?' ;;
    A1) printf '%s' 'Explain why git rebase changes commit hashes.' ;;
    A2) printf '%s' 'Explain what a mutex is and when I should use one.' ;;
    A3) printf '%s' 'Explain what eventual consistency is and what it costs.' ;;
    A4) printf '%s' 'Explain the CAP theorem and why it is often misstated.' ;;
    C1) printf '%s' 'Объясни коротко, почему git rebase меняет хеши коммитов.' ;;
    C2) printf '%s' 'Write a git commit message for this change and output nothing else: renamed scripts/emit-rule.sh to scripts/emit.sh and updated hooks/hooks.json to call the new name.' ;;
    C3) printf '%s' 'Write a Python function that returns the SHA-256 hex digest of a file, reading it in 64 KiB chunks. Output only the code.' ;;
    *)  echo "unknown prompt id: $1" >&2; exit 2 ;;
  esac
}

# run <arm> <id> <n>: one claude -p call, tokens added to the running total.
run() {
  f="$out/$1-$2-$3"
  # A finished run in PROBE_OUT is reused, so a rerun with a wider PROBE_SET
  # spends tokens only on the new prompts. Its tokens still count in the total.
  if [ -s "$f.md" ] && jq -e '.usage' "$f.json" >/dev/null 2>&1; then
    used=$(jq '.usage | (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0) + (.output_tokens // 0)' "$f.json")
    spent=$((spent + used))
    cost=$(jq -n --argjson c "$cost" --argjson x "$(jq '.total_cost_usd // 0' "$f.json")" '$c + $x')
    m=$(jq -r '.modelUsage // {} | keys | join(",")' "$f.json")
    [ -z "$m" ] || model=$m
    echo "  $1-$2-$3 cached tokens=$used total=$spent"
    return
  fi
  if [ "$spent" -ge "$PROBE_BUDGET_TOKENS" ]; then
    echo "stop: $spent tokens spent, cap $PROBE_BUDGET_TOKENS"
    exit 3
  fi
  # No --bare (skips hooks) and no --restricted (ignores the user settings
  # where enabledPlugins lives). Tools, MCP servers and slash commands are
  # removed so a run is one model turn and nothing can mutate anything.
  ( cd "$out/ws" && claude -p "$(prompt "$2")" --tools "" \
      --disallowed-tools "Bash,Edit,Write,MultiEdit,NotebookEdit,Task,Agent,WebFetch,WebSearch,Skill" \
      --strict-mcp-config --disable-slash-commands \
      --setting-sources user --no-session-persistence \
      --output-format json ) >"$f.json" 2>"$f.err" || {
    echo "claude -p failed for $1-$2-$3; see $f.err" >&2
    exit 1
  }
  jq -e '.usage' "$f.json" >/dev/null 2>&1 || {
    echo "result for $1-$2-$3 has no usage field; cannot enforce the token cap. Keys: $(jq -c 'keys' "$f.json")" >&2
    exit 1
  }
  jq -r '.result' "$f.json" >"$f.md"
  used=$(jq '.usage | (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0) + (.output_tokens // 0)' "$f.json")
  spent=$((spent + used))
  cost=$(jq -n --argjson c "$cost" --argjson x "$(jq '.total_cost_usd // 0' "$f.json")" '$c + $x')
  m=$(jq -r '.modelUsage // {} | keys | join(",")' "$f.json")
  [ -z "$m" ] || model=$m
  echo "  $1-$2-$3 tokens=$used total=$spent"
}

# arm <E|D>: presence probe, then the prompt set.
arm() {
  echo "arm $1"
  run "$1" P 1
  answer=$(tr -d '[:space:]' <"$out/$1-P-1.md" | tr '[:lower:]' '[:upper:]' | cut -c1-3)
  case "$1:$answer" in
    E:YES) echo "  presence: YES (rule is in context)" ;;
    D:NO*) echo "  presence: NO (rule is absent)" ;;
    *) echo "presence probe failed in arm $1: got '$(cat "$out/$1-P-1.md")'"; exit 4 ;;
  esac
  for id in $set_ids; do
    case "$id" in
      A*) run "$1" "$id" 1; run "$1" "$id" 2 ;;
      C*) run "$1" "$id" 1 ;;
    esac
  done
}

arm E
claude plugin disable "$plugin" >/dev/null; enabled=0
arm D
claude plugin enable "$plugin" >/dev/null; enabled=1

echo
echo "model: $model"
echo "tokens: $spent  (cost recorded, not a control: $cost USD)"

# metric <file> <name>: one field of measure.sh output.
metric() { "$measure" <"$1" | awk -v k="$2" '$1==k {print $2}'; }
banned() { "$measure" <"$1" | awk '$1=="dashes"||$1=="semicolons"||$1=="latin" {s+=$2} END {print s+0}'; }

echo
echo "arm A: sentence shape (max<=33, mean<=20, banned<=1 in E; E must beat D on max, long or banned)"
printf '  %-6s %-4s %6s %6s %5s %6s\n' prompt arm mean max long banned
verdict=working
uninformative=""
noeffect_ban=0
noeffect_mean=0
for id in $set_ids; do
  case "$id" in A*) ;; *) continue ;; esac
  e_max=0; d_max=0; e_long=0; d_long=0; e_ban=0; d_ban=0; e_mean_sum=0; d_mean_sum=0; d_clean=1
  for a in E D; do
    for n in 1 2; do
      f="$out/$a-$id-$n.md"
      mean=$(metric "$f" mean); max=$(metric "$f" max); long=$(LONG=30 metric "$f" long); ban=$(banned "$f")
      printf '  %-6s %-4s %6s %6s %5s %6s\n' "$id" "$a$n" "$mean" "$max" "$long" "$ban"
      if [ "$a" = E ]; then
        [ "$max" -gt "$e_max" ] && e_max=$max
        e_long=$((e_long + long)); e_ban=$((e_ban + ban))
        e_mean_sum=$(awk -v s="$e_mean_sum" -v x="$mean" 'BEGIN{print s+x}')
        if [ "$max" -gt 33 ] || awk -v x="$mean" 'BEGIN{exit !(x>20)}' || [ "$ban" -gt 1 ]; then
          echo "    E run breaks the rule's numbers"; verdict=noeffect
        fi
        [ "$max" -gt 40 ] && { echo "    E run has a sentence over 40 words"; verdict=noeffect; }
      else
        [ "$max" -gt "$d_max" ] && d_max=$max
        d_long=$((d_long + long)); d_ban=$((d_ban + ban))
        d_mean_sum=$(awk -v s="$d_mean_sum" -v x="$mean" 'BEGIN{print s+x}')
        # A clean baseline already obeys the rule's own numbers (30, not the
        # 33 that gives E slack): a D run with a 32-word sentence is exactly
        # what the rule exists to prevent, so that prompt is informative.
        if [ "$max" -gt 30 ] || [ "$long" -gt 0 ] || awk -v x="$mean" 'BEGIN{exit !(x>20)}' || [ "$ban" -gt 1 ]; then d_clean=0; fi
      fi
    done
  done
  if [ "$d_clean" -eq 1 ]; then
    echo "    $id: baseline already meets every threshold; uninformative, try the reserve prompt A4"
    uninformative="$uninformative $id"
    continue
  fi
  beats=0
  [ "$e_max" -lt "$d_max" ] && beats=1
  [ "$e_long" -lt "$d_long" ] && beats=1
  [ "$e_ban" -lt "$d_ban" ] && beats=1
  [ "$beats" -eq 1 ] || { echo "    $id: E does not beat D on max, long or banned"; verdict=noeffect; }
  # Only a baseline that had banned tokens can show them being removed. On
  # this harness the disabled arm already writes none, so zero is not a miss.
  [ "$d_ban" -gt 0 ] && [ "$e_ban" -ge "$d_ban" ] && noeffect_ban=$((noeffect_ban + 1))
  awk -v e="$e_mean_sum" -v d="$d_mean_sum" 'BEGIN{exit !(e>d)}' && noeffect_mean=$((noeffect_mean + 1))
done
[ "$noeffect_ban" -ge 2 ] && { echo "  banned tokens not below D on $noeffect_ban prompts"; verdict=noeffect; }
[ "$noeffect_mean" -ge 2 ] && { echo "  E mean above D mean on $noeffect_mean prompts"; verdict=noeffect; }

echo
echo "arm C: over-reach"
overreach=0
c_ok()  { echo "  ok   $1"; }
c_bad() { echo "  FAIL $1"; overreach=1; }
for id in $set_ids; do
  case "$id" in
    C1)
      for a in E D; do
        f="$out/$a-C1-1.md"
        cyr=$(od -An -tx1 "$f" | tr -s ' \n' '\n' | grep -c '^d[01]$' || true)
        lat=$(tr -cd 'A-Za-z' <"$f" | wc -c | tr -d ' ')
        if [ "$cyr" -ge $((lat * 3)) ]; then c_ok "C1 $a: reply is in Russian (cyrillic $cyr, latin $lat)"
        else c_bad "C1 $a: reply is not mainly Russian (cyrillic $cyr, latin $lat)"; fi
      done ;;
    C2)
      e="$out/E-C2-1.md"; d="$out/D-C2-1.md"
      subject=$(grep -v '^```' "$e" | grep -m1 -v '^[[:space:]]*$' || true)
      [ "${#subject}" -le 72 ] && c_ok "C2 E: subject line is ${#subject} chars" || c_bad "C2 E: subject line is ${#subject} chars"
      ew=$(wc -w <"$e" | tr -d ' '); dw=$(wc -w <"$d" | tr -d ' ')
      [ $((ew * 4)) -le $((dw * 5)) ] && c_ok "C2: E words $ew vs D words $dw" || c_bad "C2: E is longer than 1.25x D ($ew vs $dw words)"
      for name in emit-rule.sh emit.sh hooks.json; do
        grep -q "$name" "$e" && c_ok "C2 E: names $name" || c_bad "C2 E: does not name $name"
      done
      if grep -Eiq '\b(is|are) (a|an|the) (file|script|hook|command|tool)\b|\brefers to\b|\bmeans that\b' "$e"
      then c_bad "C2 E: explains basics"; else c_ok "C2 E: no explanation of basics"; fi ;;
    C3)
      e="$out/E-C3-1.md"; d="$out/D-C3-1.md"
      outside=$(awk '/^```/{f=!f;next} !f && NF {n++} END{print n+0}' "$e")
      [ "$outside" -eq 0 ] && c_ok "C3 E: nothing outside the code fence" || c_bad "C3 E: $outside prose lines outside the fence"
      ec=$(grep -c '^[[:space:]]*#' "$e" || true); dc=$(grep -c '^[[:space:]]*#' "$d" || true)
      [ "$ec" -le $((dc + 1)) ] && c_ok "C3: E comments $ec vs D $dc" || c_bad "C3: E adds comments ($ec vs $dc)"
      grep -q hashlib "$e" && c_ok "C3 E: uses hashlib" || c_bad "C3 E: no hashlib"
      el=$(wc -l <"$e" | tr -d ' '); dl=$(wc -l <"$d" | tr -d ' ')
      [ $((el * 4)) -le $((dl * 5)) ] && c_ok "C3: E lines $el vs D lines $dl" || c_bad "C3: E is longer than 1.25x D ($el vs $dl lines)" ;;
  esac
done

echo
if [ "$overreach" -eq 1 ]; then
  echo "verdict: over-reach (arm C failed in E; tighten the exemptions paragraph and rerun PROBE_SET=\"C1 C2 C3\")"
  exit 1
fi
case "$verdict" in
  working)
    if [ -n "$uninformative" ]; then echo "verdict: working, with uninformative prompts:$uninformative"
    else echo "verdict: working"; fi
    exit 0 ;;
  *)
    echo "verdict: no effect (revise the rule: the levers are the numeric cap and the ban list)"
    exit 1 ;;
esac
