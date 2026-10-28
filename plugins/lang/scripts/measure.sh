#!/usr/bin/env sh
# Score English prose on stdin for simpler-English shape. Prints one metric per
# line so a caller can pick a field with awk '$1=="max"{print $2}'.
#
#   measure.sh [-d] [-q] < prose.md
#     -d  also print every sentence with its word count
#     -q  treat text inside double quotes as a mention, not a use (a rule that
#         forbids e.g. must be allowed to name it)
#   LONG=<n>  words above which a sentence counts as long (default 30)
#
# A sentence ends at a token that ends in . ! or ? (a closing quote, bracket or
# emphasis marker may follow), is not a listed abbreviation or a single initial, and is
# followed by a token that starts with a capital, a digit or an opening
# quote/bracket, or by the end of the paragraph. Headings, fenced code and
# table rows are skipped; list and blockquote markers are stripped; an inline
# code span counts as one word. Hard-wrapped lines join into one paragraph.
#
# Two details are load-bearing. Bracket expressions put ] first and never
# contain a backslash: POSIX regcomp (busybox awk) treats a backslash inside
# brackets as a literal, which silently disables the terminator match.
# Placeholders are multi-letter (CODE, QUOTE): a one-letter placeholder before
# a period matches the single-initial guard and suppresses a split.
set -eu
LC_ALL=C; export LC_ALL
debug=0; quiet=0
for a in "$@"; do
  case "$a" in
    -d) debug=1 ;;
    -q) quiet=1 ;;
    *)  echo "usage: measure.sh [-d] [-q] < prose" >&2; exit 2 ;;
  esac
done
exec awk -v long="${LONG:-30}" -v debug="$debug" -v quiet="$quiet" '
function emit(s, w) {
  sentences++; words += w
  if (w > max) { max = w; longest = s }
  if (w > long) nlong++
  if (debug) printf "%3d  %s\n", w, s
}
function flush(   n, i, t, nxt, cur, wc, bare) {
  if (buf == "") return
  n = split(buf, tok, /[ \t]+/)
  cur = ""; wc = 0
  for (i = 1; i <= n; i++) {
    t = tok[i]
    if (t == "") continue
    cur = (cur == "") ? t : cur " " t
    wc++
    if (t !~ /[.!?][]")*_]*$/) continue
    bare = tolower(t)
    gsub(/^["([*_]+/, "", bare); gsub(/[]")*_]+$/, "", bare)
    if (bare ~ /^[a-z]\.$/) continue
    if (bare ~ /^(etc|vs|cf|viz|al|mr|mrs|dr|no|approx|fig)\.$/) continue
    if (i < n) { nxt = tok[i+1]; if (nxt !~ /^["([*_]*[A-Z0-9]/) continue }
    emit(cur, wc); cur = ""; wc = 0
  }
  if (wc > 0) emit(cur, wc)
  buf = ""
}
/^(```|~~~)/ { flush(); fence = !fence; next }
fence { next }
/^[ \t]*$/ || /^#/ || /^[ \t]*\|/ { flush(); next }
{
  line = $0
  sub(/^[ \t]*>[ \t]?/, "", line)
  if (line ~ /^[ \t]*([-*+]|[0-9]+[.)])[ \t]+/) { flush(); sub(/^[ \t]*([-*+]|[0-9]+[.)])[ \t]+/, "", line) }
  gsub(/`[^`]*`/, "CODE", line)
  if (quiet) gsub(/"[^"]*"/, "QUOTE", line)
  dashes += gsub(/—|–| -- /, "&", line)
  semis  += gsub(/;/, "&", line)
  latin  += gsub(/e\.g\.|i\.e\.|cf\.|viz\.|et al\./, "&", line)
  gsub(/e\.g\./, "eg", line); gsub(/i\.e\./, "ie", line); gsub(/\.\.\./, ".", line)
  buf = (buf == "") ? line : buf " " line
}
END {
  flush()
  if (sentences == 0) { print "sentences 0"; exit }
  printf "sentences %d\nwords %d\nmean %.1f\nmax %d\nlong %d\ndashes %d\nsemicolons %d\nlatin %d\nlongest: %s\n",
         sentences, words, words / sentences, max, nlong, dashes, semis, latin, longest
}'
