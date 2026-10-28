#!/usr/bin/env sh
# Print the SessionStart payload for one rule: emit-rule.sh <rule>
# <rule> is the base name of a file in rules/, for example soft-wrap.
#
# Deliberately just a `cat`. The JSON is built ahead of time by scripts/build.sh
# and committed as hooks/<rule>.json, so this cannot fail on a machine without
# jq, and there is no runtime string-escaping to get wrong. If the payload is
# missing, cat exits non-zero and the failure is visible rather than producing
# malformed JSON the CLI would silently drop.
set -eu

case "${1-}" in
  ''|*[!a-z0-9-]*) echo "usage: emit-rule.sh <rule>" >&2; exit 2 ;;
esac

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
exec cat "$root/hooks/$1.json"
