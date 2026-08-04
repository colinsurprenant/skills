#!/usr/bin/env bash
# Render statusline.js against crafted payloads and assert the colour band.
#
# The bands exist to warn before a context wall, so the failure that matters is
# a wrong COLOUR on a right number: the percentage has always had a fallback for
# missing token counts, and when the colour did not, a 97% bar rendered green.
# Every case below is a rendered payload, not a reading of the arithmetic.
#
# Run against another build to compare behaviour (e.g. a control run proving a
# case actually fails before a fix):
#
#     git show HEAD:trim/statusline.js > /tmp/old.js
#     STATUSLINE=/tmp/old.js trim/statusline.test.sh
set -u

command -v node >/dev/null 2>&1 || { echo "statusline.test: node not found" >&2; exit 127; }

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
S=${STATUSLINE:-$dir/statusline.js}
[ -r "$S" ] || { echo "statusline.test: cannot read $S" >&2; exit 66; }

# Match ONLY the escape code immediately preceding the bar glyphs; the shell
# prefix (branch, cwd) emits its own colours earlier in the line. The optional
# skull is part of the top band's segment.
band() {
  seg=$(printf '%s' "$1" | node "$S" 2>/dev/null \
        | grep -oE $'\033\\[[0-9;]+m(\xf0\x9f\x92\x80 )?[█░]' | tail -1 | cat -v)
  case "$seg" in
    *'^[[5;31m'*)     echo "RED" ;;
    *'^[[38;5;208m'*) echo "ORANGE" ;;
    *'^[[33m'*)       echo "YELLOW" ;;
    *'^[[32m'*)       echo "GREEN" ;;
    *)                echo "NONE" ;;
  esac
}
pct() { printf '%s' "$1" | node "$S" 2>/dev/null | grep -oE '[0-9]+%' | tail -1; }

fail=0
t() { # label json expected
  g=$(band "$2"); p=$(pct "$2")
  st=OK; [ "$g" = "$3" ] || { st="**MISMATCH**"; fail=$((fail+1)); }
  printf '%-44s bar=%-5s expect=%-7s got=%-7s %s\n' "$1" "${p:-none}" "$3" "$g" "$st"
}

W200='"context_window_size":200000'
W1M='"context_window_size":1000000'
u() { echo "\"current_usage\":{\"input_tokens\":$1}"; }

# No session_id in any payload: keeps the bridge-file and debug-log writes off.
echo "--- token counts absent: colour must track the displayed percentage ---"
t "200k win, remaining 3%, no usage" "{\"context_window\":{\"remaining_percentage\":3,$W200}}" RED
t "200k win, remaining 8%, no usage" "{\"context_window\":{\"remaining_percentage\":8,$W200}}" RED
t "200k win, remaining 50%, no usage" "{\"context_window\":{\"remaining_percentage\":50,$W200}}" GREEN
t "no window at all, remaining 3%" '{"context_window":{"remaining_percentage":3}}' RED

echo "--- 1M window: 200k/400k/700k ---"
t "1M, 150k tokens" "{\"context_window\":{\"remaining_percentage\":85,$W1M,$(u 150000)}}" GREEN
t "1M, 250k tokens" "{\"context_window\":{\"remaining_percentage\":75,$W1M,$(u 250000)}}" YELLOW
t "1M, 405775 tokens" "{\"context_window\":{\"remaining_percentage\":59,$W1M,$(u 405775)}}" ORANGE
t "1M, 750k tokens" "{\"context_window\":{\"remaining_percentage\":25,$W1M,$(u 750000)}}" RED

echo "--- 200k window: 140k/160k/180k ---"
t "200k, 100k tokens" "{\"context_window\":{\"remaining_percentage\":50,$W200,$(u 100000)}}" GREEN
t "200k, 150k tokens" "{\"context_window\":{\"remaining_percentage\":25,$W200,$(u 150000)}}" YELLOW
t "200k, 170k tokens" "{\"context_window\":{\"remaining_percentage\":15,$W200,$(u 170000)}}" ORANGE
t "200k, 190k tokens" "{\"context_window\":{\"remaining_percentage\":5,$W200,$(u 190000)}}" RED

echo "--- exact thresholds: every band edge is exclusive-below ---"
t "1M, exactly warnAt 200k" "{\"context_window\":{\"remaining_percentage\":80,$W1M,$(u 200000)}}" YELLOW
t "1M, exactly critAt 400k" "{\"context_window\":{\"remaining_percentage\":60,$W1M,$(u 400000)}}" ORANGE
t "1M, exactly skullAt 700k" "{\"context_window\":{\"remaining_percentage\":30,$W1M,$(u 700000)}}" RED

# The ordering check restates the formula rather than importing it (statusline.js
# is a stdin script, not a module), so it would keep passing against a source that
# had moved on. Pin the two together: change the thresholds, change this too.
echo "--- threshold formula matches the source ---"
want='Math.min(200_000, 0.70 * win) Math.min(400_000, 0.80 * win) Math.min(700_000, 0.90 * win) '
got=$(grep -oE 'Math\.min\([0-9_]+, 0\.[0-9]+ \* win\)' "$S" | tr '\n' ' ')
if [ "$got" = "$want" ]; then
  echo "  thresholds in $(basename "$S") match the ordering check  OK"
else
  echo "  **MISMATCH** source has: $got"
  echo "               check has: $want"
  fail=$((fail+1))
fi

# Property the caps have to preserve: a bigger window must never warn earlier.
echo "--- threshold ordering across window sizes ---"
node -e '
let bad = 0;
for (let w = 10_000; w <= 2_000_000; w += 10_000) {
  const warn = Math.min(200_000, 0.70 * w);
  const crit = Math.min(400_000, 0.80 * w);
  const skull = Math.min(700_000, 0.90 * w);
  if (!(warn <= crit && crit <= skull)) { bad++; console.log("  ORDER VIOLATION at", w, warn, crit, skull); }
}
console.log(bad === 0 ? "  warnAt <= critAt <= skullAt for all windows 10k..2M  OK" : `  ${bad} violations`);
process.exit(bad === 0 ? 0 : 1);
' || fail=$((fail+1))

echo
if [ "$fail" -eq 0 ]; then
  echo "PASS: all cases"
else
  echo "FAIL: $fail case(s)"
fi
exit $((fail > 0))
