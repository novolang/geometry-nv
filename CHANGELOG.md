# Changelog

All notable changes to geometry-nv are recorded here. The format is
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
package follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
with the pre-1.0 rule that a breaking change bumps the MINOR number.

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
