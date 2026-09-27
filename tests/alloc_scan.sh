#!/usr/bin/env bash
# tests/alloc_scan.sh — nothing in `geompoint`, `geomrect` or
# `geomxform` allocates, as a check that can fail.
#
# Those three modules are the half a device runs.  What makes them
# usable there is that they put nothing on the heap.  The emitted LLVM
# is where that is true or false, so this reads it.
#
# There are three runs, because a check that cannot fail is not a check.
#
#   1. Every function in the three modules appears in the IR of
#      `tests/alloc_probe.nv` at `--opt=0`, and none of them calls the
#      allocator, directly or through a runtime entry point that
#      allocates on the caller's behalf.
#   2. The scan still sees an allocation.  A heap list literal is
#      spliced into `geompoint.ptf` on a copy of the tree, with every
#      `@tier(embedded)` line taken off so the compiler is not what
#      refuses it, and the scan has to name it.
#   3. The compiler still refuses the same splice with
#      `@tier(embedded)` left on.  An annotation that stopped being
#      enforced looks exactly like one that passes.
#
# Run from anywhere:  bash tests/alloc_scan.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG="$(cd "$HERE/.." && pwd)"
NOVO="${NOVO:-$HOME/.novo/bin/novo}"
SCAN="$HERE/alloc_scan.py"

PASS=0; FAIL=0
pass() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ✗ $1"; [ -n "${2:-}" ] && echo "$2" | sed 's/^/      /'; FAIL=$((FAIL + 1)); }

echo ""
echo "══════════════════════════════════════════"
echo "  geometry-nv — nothing in the device modules allocates"
echo "══════════════════════════════════════════"

[ -x "$NOVO" ] || { fail "novo present at $NOVO"; echo "pass=$PASS fail=$FAIL"; exit 1; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/geometry-nv-alloc.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# The splice is a heap list literal bound in `ptf`, and read, so it
# cannot be folded away.  The second argument says whether the
# `@tier(embedded)` annotations stay.
splice() {  # splice <src dir> <keep-tier: yes|no>
  python3 - "$1" "$2" <<'PY'
import glob, os, sys
src, keep_tier = sys.argv[1], sys.argv[2]
path = os.path.join(src, 'geompoint.nv')
s = open(path).read()
anchor = ("pub @tier(embedded)\n"
          "fn ptf(x: Float, y: Float) -> GeomPointF\n"
          "    GeomPointF { x: x, y: y }\n")
if anchor not in s:
    sys.exit("anchor not found — alloc_scan.sh's splice is measuring nothing")
new = ("pub @tier(embedded)\nfn ptf(x: Float, y: Float) -> GeomPointF\n"
       "    let probe = [1, 2, 3]\n"
       "    GeomPointF { x: x + (probe[0] as Float), y: y }\n")
open(path, 'w').write(s.replace(anchor, new))
if keep_tier == "no":
    # Every caller of `ptf` carries `@tier(embedded)` too, and an
    # annotated function may not call an unannotated one, so the
    # annotation comes off all three modules.  What is left is a core
    # the compiler no longer constrains, in which the emitted IR is the
    # only thing that can catch the allocation.
    for f in glob.glob(os.path.join(src, '*.nv')):
        t = open(f).read()
        t = t.replace("pub @tier(embedded)\nfn ", "pub fn ")
        t = t.replace("@tier(embedded)\nfn ", "fn ")
        open(f, 'w').write(t)
PY
}

build_probe() {  # build_probe <tree>
  ( cd "$1" && NOVO_LEAK_CHECK=0 timeout 900 "$NOVO" build --opt=0 \
      -o "$1/probe.bin" tests/alloc_probe.nv ) >"$1/build.log" 2>&1
}

# ── 1. nothing in the core allocates ─────────────────────────────────

cp -r "$PKG" "$WORK/ok" 2>/dev/null
rm -rf "$WORK/ok/_novo"
if build_probe "$WORK/ok"; then
  IR="$WORK/ok/_novo/alloc_probe.ll"
  if [ -s "$IR" ]; then
    report="$(python3 "$SCAN" "$IR")"
    if [ "${report#OK}" != "$report" ]; then
      pass "nothing in the device modules allocates — ${report#OK }"
    else
      fail "nothing in the device modules allocates" "${report#FAIL }"
    fi
  else
    fail "nothing in the device modules allocates" "no _novo/alloc_probe.ll emitted"
  fi
else
  fail "the allocation probe builds" "$(grep -E 'error' "$WORK/ok/build.log" | head -5)"
fi

# ── 2. the scan still sees an allocation ─────────────────────────────

cp -r "$PKG" "$WORK/neg" 2>/dev/null
rm -rf "$WORK/neg/_novo"
if splice "$WORK/neg/src" no >"$WORK/splice.log" 2>&1 \
   && build_probe "$WORK/neg"; then
  neg="$(python3 "$SCAN" "$WORK/neg/_novo/alloc_probe.ll")"
  if [ "${neg#FAIL}" != "$neg" ] && printf '%s' "$neg" | grep -q 'geompoint_ptf'; then
    pass "the scan still sees an allocation spliced into ptf"
  else
    fail "the scan still sees an allocation spliced into ptf" \
         "expected a finding naming geompoint_ptf; got: $neg"
  fi
else
  fail "the negative control builds" \
       "$(cat "$WORK/splice.log"; grep -E 'error' "$WORK/neg/build.log" | head -5)"
fi

# ── 3. the compiler still refuses the splice ─────────────────────────

cp -r "$PKG" "$WORK/tier" 2>/dev/null
rm -rf "$WORK/tier/_novo"
splice "$WORK/tier/src" yes >"$WORK/tsplice.log" 2>&1
if build_probe "$WORK/tier"; then
  fail "@tier(embedded) still refuses a heap list literal" \
       "the build succeeded with a list literal in an @tier(embedded) function"
else
  pass "@tier(embedded) still refuses a heap list literal in ptf"
fi

echo ""
echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
