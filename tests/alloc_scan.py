#!/usr/bin/env python3
"""Read the emitted LLVM for geometry-nv's allocation probe and say
whether any function in `geompoint`, `geomrect` or `geomxform` can put a
cell on the heap.

Run by tests/alloc_scan.sh three times: once on the package as it
stands, and twice on copies with an allocation spliced into the core.
Those two copies are what the scan and the compiler respectively have
to catch, because a check that cannot fail is not a check.

The IR is emitted at `--opt=0`.  At the default optimisation level the
probe inlines into `novo_main`, no function is left to attribute an
allocation to, and the scan would pass over an empty file.
"""
import re
import sys

# Every way a function can put a cell on the heap.  `novo_alloc*` is the
# direct one, and `novo_vec_alloc*` is how a list literal is made.  The
# others allocate inside the runtime on the caller's behalf, and a
# search for the first alone would miss them.
BOXERS = ['novo_alloc', 'novo_vec_alloc', 'novo_vec_push', 'novo_some_int',
          'novo_some_float', 'novo_str_byte_at(', 'novo_bytes_byte_at(',
          'novo_str_concat', 'novo_float_to_str']

# The three modules a device build uses.  `geompoly`, `geompack`,
# `geomtrig` and `geomtext` allocate or call the C maths library, which
# is what they are for, and are not matched.
CORE = re.compile(r'^novo_user_(geompoint|geomrect|geomxform)_')

FNS = re.compile(r'^define[^\n]*?@([A-Za-z0-9_.]+)\([^\n]*\{\n(.*?)\n\}',
                 re.S | re.M)

# The three modules hold 92 functions and the probe reaches every one.
# Fewer than this in the IR means the probe or the name scheme moved,
# and that the scan is measuring nothing.
FLOOR = 92


def main(path):
    src = open(path).read()
    seen, offenders = 0, []
    for m in FNS.finditer(src):
        name, body = m.group(1), m.group(2)
        if not CORE.match(name):
            continue
        seen += 1
        for boxer in BOXERS:
            if 'call' in body and ('@' + boxer) in body:
                offenders.append('%s: %s' % (name, boxer.rstrip('(')))
    if seen < FLOOR:
        print('FAIL only %d core function(s) in the IR, expected at least '
              '%d — the probe or the name scheme moved, and this check was '
              'measuring nothing' % (seen, FLOOR))
    elif offenders:
        print('FAIL ' + '; '.join(sorted(set(offenders))))
    else:
        print('OK %d function(s) in geompoint, geomrect and geomxform, '
              'zero heap cells' % seen)


if __name__ == '__main__':
    main(sys.argv[1])
