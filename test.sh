#!/usr/bin/env bash
# test.sh — offline regression test for gh-issues-map.
#
# Runs the script against a stub `gh` (no network, no repo) and asserts the
# rendered map. Pins, in particular, that a PRD nested under another PRD
# renders its children instead of being flattened to a leaf.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# --- stub gh ---------------------------------------------------------------
mkdir -p "$work/bin"
cat > "$work/bin/gh" <<'STUB'
#!/usr/bin/env bash
if [ "$1" = "repo" ]; then echo "test/repo"; exit 0; fi
if [ "$1" = "issue" ] && [ "$2" = "list" ]; then cat "$GHMAP_TEST_RAW"; exit 0; fi
echo "stub gh: unhandled: $*" >&2
exit 1
STUB
chmod +x "$work/bin/gh"

# --- fixture ---------------------------------------------------------------
# Fields, in the order the script's jq emits them:
#   number state title blockers open_blockers count parent sub_total sub_done labels
gen() {
  printf '%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\n' \
    "$1" "$2" "$3" "${4:-}" "${5:-}" "$6" "${7:-}" "$8" "$9" "${10:-}"
}
{
  gen 1  OPEN   "Spec: root PRD"        ""   ""  0 ""  3 1 "spec"
  gen 2  CLOSED "done leaf"             ""   ""  0 1   0 0 ""
  gen 3  OPEN   "Spec: child spec"      ""   ""  0 1   2 0 "spec"
  gen 4  OPEN   "leaf with children"    ""   ""  0 3   1 0 ""
  gen 5  OPEN   "blocked leaf"          "#4" "4" 1 3   0 0 ""
  gen 6  OPEN   "Spec: grandchild spec" ""   ""  0 4   1 0 "spec"
  gen 7  OPEN   "deep leaf"             ""   ""  0 6   0 0 ""
  gen 8  OPEN   "orphan leaf"           ""   ""  0 ""  0 0 ""
} > "$work/raw.txt"

run() { GHMAP_TEST_RAW="$work/raw.txt" PATH="$work/bin:$PATH" NO_COLOR=1 "$here/gh-issues-map" "$@"; }

# --- assertions ------------------------------------------------------------
out=$(run)
fail=0

# want <description> <fixed string>
want() {
  if printf '%s\n' "$out" | grep -qF -- "$2"; then
    printf 'ok   %s\n' "$1"
  else
    printf 'FAIL %s — missing: %s\n' "$1" "$2"
    fail=1
  fi
}

# want_re <description> <extended regex>
want_re() {
  if printf '%s\n' "$out" | grep -qE -- "$2"; then
    printf 'ok   %s\n' "$1"
  else
    printf 'FAIL %s — no line matches: %s\n' "$1" "$2"
    fail=1
  fi
}

# Nested PRDs are grouped and indented one level per depth.
want_re "child PRD is a nested header at depth 1"  '^  PRD: Spec: child spec'
want_re "grandchild PRD nests at depth 2"          '^    PRD: leaf with children'
want_re "great-grandchild PRD nests at depth 3"    '^      PRD: Spec: grandchild spec'

# …and their leaves render beneath their own header, not dropped.
want_re "child leaf row at depth 1"                '^    4  OPEN'
want_re "grandchild leaf row at depth 2"           '^      6  OPEN'
want "deep leaf rendered"                          "deep leaf"
want "blocked leaf keeps its gate"                 "waiting (#4)"
want "orphan stays unassigned"                     "orphan leaf"

# Frontier rolls nested PRDs up, each depth further indented.
want "frontier names the nested PRD"               "    PRD: Spec: child spec (#3)"
want "frontier lists the nested leaf"              "      #4 leaf with children"
want "frontier descends another level"             "        #6 Spec: grandchild spec"
want "frontier reaches the deepest leaf"           "          #7 deep leaf"

# Flat mode still lists every issue.
flat=$(run --flat)
for n in 1 2 3 4 5 6 7 8; do
  if printf '%s\n' "$flat" | grep -qE "^  $n  "; then
    printf 'ok   flat lists #%s\n' "$n"
  else
    printf 'FAIL flat missing #%s\n' "$n"
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  echo
  echo "--- grouped output ---"
  printf '%s\n' "$out"
  exit 1
fi
echo
echo "all assertions passed"
