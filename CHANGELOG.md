# Changelog

All notable changes to geometry-nv are recorded here. The format is
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
package follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
with the pre-1.0 rule that a breaking change bumps the MINOR number.

## 0.1.0 — 2026-09-27

The first implementation of the interface published as 0.0.1: points,
vectors and sizes, rectangles, affine transforms, polygons and a shelf
packer, with three modules that build for a microcontroller.

### Changed, breaking

- Eleven functions moved out of `geompoint`, `geomrect` and
  `geomxform`, because each one needs the C maths library or a heap,
  and one such function anywhere in a module stops that module linking
  for a device.  The interface claimed all three modules for a device
  build and could not have kept the claim with these functions in them.
  - `geompoint.length`, `normalize`, `distance`, `angle_of` and
    `from_angle`, and `geomxform.rotation`, `rotation_about` and
    `rotated`, are in the new module `geomtrig`, under the same names.
  - `geompoint.format`, `geomrect.format` and `geomxform.format_matrix`
    are `geomtext.format_point`, `format_rect` and `format_matrix`.
  - `geomrect.corners` and `geomxform.apply_points` are
    `geompoly.corners` and `geompoly.apply_points`.
- `geomrect.empty()` has its low corner at positive infinity and its
  high corner at negative infinity, where the interface documented four
  zeros.  With four zeros, `extend` could not tell the empty rectangle
  from the point at the origin, and a bounding box folded from `empty()`
  kept the origin.  `empty_i()` keeps four zeros.
- `geomxform.is_identity`, `is_translation` and `is_axis_aligned` are
  exact.  The interface's comment on `is_identity` mentioned a tolerance
  the signature has no parameter for; `near(t, identity(), eps)` is the
  question with one.

### Added

- `geomxform.about(t, pivot)`: `t` performed about a point.
  `scaling_about` and `geomtrig.rotation_about` are built on it.

### Behaviour

- Every function in `geompoint`, `geomrect` and `geomxform` is
  `@tier(embedded)`.  `tests/embedded_probe.nv` builds the three for
  `--target=nrf52-qemu` and checks four exact answers under QEMU, and
  `tests/alloc_scan.sh` reads their emitted LLVM for a call to the
  allocator and finds none.
- `to_int_floor`, `to_int_round`, `to_int_outer` and `to_int_inner`
  convert with `as Int`, and stop the program on a coordinate that is
  not a number or is outside the range of `Int` (SPEC section 13.3).
- `extend` keeps a rectangle of zero width or height, so the second
  step of a fold keeps the first point.  A rectangle that is inverted on
  either axis holds no point and is replaced.
- `inflate` and `inset` answer `empty()` for an empty rectangle and for
  one shrunk past its middle.
- `is_invertible` is relative: the determinant must exceed `1e-12` times
  the square of the largest linear entry.
- A polygon copies the list it is made from, and `points_of` answers a
  copy.
- `geompoly.contains` is the winding-number test; the even-odd rule
  reads the parity of the same crossings.  `is_convex` also requires the
  ring to go round once, so a star drawn in one stroke is not convex.
- `geompoly.simplify` is Ramer-Douglas-Peucker on the closed ring, cut
  at the first vertex and the vertex farthest from it.
- `geompoly.segments_cross` counts segments that touch at an end or
  overlap on one line.
- `geompack.place` answers a new bin and leaves its argument unchanged;
  `place_all` copies once for the whole list.  A rectangle with a width
  or height that is not positive is recorded as a failed placement.
- `order_by_height` and `order_by_area` are stable.
- The toolchain floor is 0.13.0. The bodies are written for it and use
  no workaround: `math.abs` builds for a device from that release, and
  the two orderings sort a list of pairs with `list.sort`.

## 0.0.2 — 2026-09-15

- README rewritten to the package README style guide (docs/writing-a-readme.md); no change to the interface.

## 0.0.1 — 2026-09-11

The **interface**: every signature and every effect row, and no bodies.
`stability = "draft"`, and the release is recorded `implemented = false`.

### Added

- `geompoint` — `GeomPointF`, `GeomPointI`, `GeomVecF`, `GeomVecI`,
  `GeomSizeF`, `GeomSizeI` as `@value` structs, and the vector algebra
  over them. A position and a displacement are separate types because
  a transform treats them differently and the mistake is otherwise
  silent. Two flavours rather than one generic, because a generic
  function whose return type applies a generic head is not emitted for
  a cross-module call and a library is nothing but those.
- `geomrect` — `GeomRectF` and `GeomRectI` as two corners, half-open, in
  euclid's `Box2D` shape rather than its `Rect`. An empty rectangle is a
  VALUE: `intersection` returns one instead of an optional, which is
  both what SPEC §14.5 allows and what clipping actually wants.
- `geomxform` — `GeomXform`, six Floats in SVG's `matrix(a b c d e f)`
  order, with `compose(first, second)` reading left to right.
  `is_invertible` and a total `invert` rather than one fallible call.
  `mapping` is the one a plot is built out of.
- `geompoly` — one closed ring, the shoelace area, the winding, and
  containment under both SVG fill rules. The centroid is weighted by
  AREA, which is the fix atlas's vertex-average version needs.
- `geompack` — a shelf packer: `place` is online, the state is three
  integers per shelf, and `order_by_height` answers a permutation
  because a list of `@value` elements cannot be sorted.
- `tests/embedded_probe.nv` — the device claim, built for
  `--target=nrf52-qemu`. It reaches `geompoint`, `geomrect` and
  `geomxform` and not the two modules that allocate.

### Decided

- **The packing algorithm was an open choice, not a port.** The plan's
  row said "the packing arithmetic atlas carries"; atlas carries a
  uniform 16-by-6 cell grid for ASCII glyphs and a bit-packed tile id,
  and no rectangle packer at all. Shelf was chosen over skyline for a
  bounded state — three integers per shelf against a segment list that
  grows with the width — and because a uniform grid is a shelf pack
  whose rectangles happen to be equal. The README carries the argument.
- **No unit or space type parameters.** euclid's `Point2D<T, U>` tags a
  point with the space it lives in. The generic-emission limit above
  makes every tagged type unreachable across a module boundary, so the
  idea is recorded rather than implemented.

### Known

- **`compose` has no `then` alias.** `then` is a reserved word — it
  separates an inline conditional's branches (SPEC §1.3) — so the
  reading-order spelling is `compose(first, second)` and the parameter
  names carry the argument.
- No polygon with holes, and no boolean operations between polygons.
  Both are a different type beside this one rather than a change to it.
