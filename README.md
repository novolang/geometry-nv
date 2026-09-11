# geometry-nv

**Status: NOT IMPLEMENTED — interface only.**

Every public function below is published with its signature and its
effect row, and every body is `todo()`. Installing this package works;
calling it panics with `not implemented`.

## What this is

Two-dimensional geometry as arithmetic: points, vectors and sizes in a
Float flavour and an Int flavour, rectangles with the
union/intersection/containment algebra, 2x3 affine transforms, polygons
with area, winding and containment, and a shelf packer for fitting
rectangles into a bin.

It is the bottom of novo-lang's drawing stack.
[`svg-nv`](https://github.com/novolang/svg-nv) takes its points and its
transforms; [`plot-nv`](https://github.com/novolang/plot-nv) lays a
figure out with its rectangles; a glyph atlas or a sprite sheet is built
with its packer.

```
novo pkg add geometry-nv
novo pkg build
novo test
```

## The one example that will work

A plot's axes, which is three calls and no allocation:

```novo
use geomrect
use geomxform
use geompoint

// The pixel rectangle the data is drawn into: the canvas less its
// gutters — 40 on the left for tick labels, 30 at the bottom for the
// axis, 10 of margin elsewhere.
fn plot_area(canvas_w: Float, canvas_h: Float) -> GeomRectF
    geomrect.inset(geomrect.of_xywh(0.0, 0.0, canvas_w, canvas_h), 40.0, 10.0, 10.0, 30.0)

// Data space in, pixel space out.  The destination's y runs UPWARDS
// from the bottom of the plot area, so `mapping` produces a negative
// vertical scale and the flip every plotting library needs is not a
// special case — it is what asking for that rectangle means.
fn data_to_pixels(data: GeomRectF, area: GeomRectF) -> GeomXform
    let flipped = geomrect.of_xywh(area.min.x, area.max.y,
                                   geomrect.width(area), 0.0 - geomrect.height(area))
    geomxform.mapping(data, flipped)

fn place(t: GeomXform, x: Float, y: Float) -> GeomPointF
    geomxform.apply_point(t, geompoint.ptf(x, y))
```

## The layer, and why

`core`. Every function here is an expression over numbers the caller
already holds: nothing is read, nothing is written, no clock is
consulted, and the state a call carries is a handful of Floats in a
frame. There is no `[dependencies]` table either — a package that needed
a dependency to add two Floats would be the wrong package.

The device claim is MADE rather than skipped. `tests/embedded_probe.nv`
is a firmware `main` that maps a viewport, clips a rectangle and
measures a vector, and the audit's `core-embedded` row builds it for
`--target=nrf52-qemu`. It covers `geompoint`, `geomrect` and
`geomxform` — the unboxed arithmetic — and deliberately not `geompoly`
or `geompack`, which hold lists. That is the claim made honestly rather
than broadly: the geometry a device does is the scalar half.

## The load-bearing interface

```novo ignore
@value pub struct GeomPointF    // two Floats, in registers, no heap cell
@value pub struct GeomRectF     // two corners — min and max, half-open
@value pub struct GeomXform     // six Floats, in SVG's matrix(a b c d e f) order

pub fn intersection(a: GeomRectF, b: GeomRectF) -> GeomRectF   // never an optional
pub fn mapping(from: GeomRectF, to: GeomRectF) -> GeomXform    // one space onto another
pub fn apply_point(t: GeomXform, p: GeomPointF) -> GeomPointF  // translation applies
pub fn apply_vec(t: GeomXform, v: GeomVecF) -> GeomVecF        // translation does NOT
```

Not a trait and not a state machine — an **unboxed layout**, and every
other decision in the package follows from it.

`@value` (SPEC §14) lays these structs out with true field widths,
passes them in registers, and stores a `[GeomPointF]` as one flat buffer
with no per-element cell and no per-element reference count (§14.6).
That is what makes the device claim possible and what makes a polygon of
ten thousand vertices one allocation.

What it costs is spelled out in §14.5, and it shapes every signature
here: an unboxed struct may be a local, a parameter, a return, a field
of another `@value` struct, and an element of a list — **and nothing
else**. Not an optional payload, not a `Result` payload, not a tuple
element, not an enum payload, not a field of a boxed struct. So:

- **`intersection` returns a possibly-empty rectangle, not `?GeomRectF`.**
  `is_empty` is the question. This is the better API in any case: an
  intersection coming back empty is the ordinary outcome of clipping,
  not a failure, and `?` would have said otherwise.
- **`invert` returns the identity for a singular transform, and
  `is_invertible` is asked first.** A predicate and a total function
  rather than one fallible call. The identity is the safe wrong answer:
  a caller who skipped the check sees untransformed coordinates, not a
  matrix that turns every later point into a NaN and draws nothing.
- **`GeomPoly` and `GeomBin` are boxed**, and hold their unboxed parts
  in lists. They could not hold one as a plain field.
- **A consumer that wants one of these inside an enum payload carries
  the numbers instead.** svg-nv's `SvgTransform` is that bridge written
  once, with `geomxform.format_matrix` as the agreed spelling so the two
  packages cannot disagree about argument order.
- **The comparison operators and string interpolation are out**, so the
  package owns `near` and `format`. Comparing two Floats for exact
  equality was the wrong test anyway.

The two flavours — `GeomPointF` and `GeomPointI` — are written out
rather than generated from a `GeomPoint<T>`, because a generic function
whose return type applies a generic head is not emitted for a call from
another module on this toolchain, and a library is nothing but
cross-module calls. The division earns its keep regardless: a Float
point is a position and an Int point is a pixel, and `to_int_floor`
(the pixel a position falls inside) versus `to_int_round` (the nearest
pixel) is a choice worth making on purpose.

## What it ports

[euclid](https://github.com/servo/euclid) for the types and the
transform algebra, and the [shapely](https://shapely.readthedocs.io/)
subset a drawing program uses for the polygon predicates. Both are
permissively licensed and both are the reference for the test vectors.
The naming follows euclid where the two agree: `GeomRectF` is its
`Box2D` (two corners) rather than its `Rect` (origin and size), because
the corner form is what the algebra wants.

Two departures, both deliberate:

- **No unit or space type parameters.** euclid's `Point2D<T, U>` tags a
  point with the space it lives in, so screen coordinates and world
  coordinates cannot be mixed up. It is a good idea that this toolchain
  cannot carry: the generic emission limit above means every tagged type
  would be unreachable across a module boundary.
- **One ring per polygon, not many.** A polygon with holes is a list of
  rings with a fill rule, and that is a different type with a different
  containment test and a different area. Neither consumer needs it — a
  district boundary and a plot's fill are both simple rings — and adding
  it later is a new type beside this one rather than a change to it.

## The packing algorithm, and why it is shelf

The plan's row for this package says "the packing arithmetic atlas
carries". **atlas carries no packer.** What it has is a uniform cell
grid — 16 columns by 6 rows of identical cells, one per printable ASCII
glyph, with the cell address a division and a remainder
(`orbit/atlas/src/text.nv`). Its `pack` function is a different thing
entirely: bit-packing a z/x/y tile triple into one Int
(`orbit/atlas/src/tiles.nv`), an encoding with no rectangles in it.

So the choice was open, and it is **shelf (next-fit decreasing
height)**:

- It generalises what atlas already does. A uniform grid IS a shelf pack
  in which every rectangle has the same height, so the glyph atlas
  becomes a special case rather than something to replace — and a
  variable-width font, which is why that grid wastes the space it does,
  starts working with no new concept.
- Its state is three integers per shelf, and the number of shelves is
  bounded by the bin's height over the shortest rectangle. That is a
  bound a device can reason about. Skyline packs tighter but keeps a
  segment list whose length grows with the width and the input, which is
  an unbounded allocation in the middle of an atlas build.
- It is online. `place` takes one rectangle and returns the bin, so a
  caller streaming glyphs out of a font never holds them all.

Skyline and MaxRects are absent on purpose, and the note is here so that
adding one later is a decision rather than an omission: they pack
tighter, they are worth having when a texture page is the scarce
resource, and they belong beside `place` under their own names.

**The caller orders the input.** "Decreasing height" is the half that
makes shelf packing good, and `order_by_height` answers a permutation —
a `[Int]` of indices — rather than a sorted list. Partly because a
`[GeomSizeI]` cannot be sorted at all (the sort lowering assumes boxed
element cells, §14.6), and partly because it is the better API: a caller
packing glyphs has a codepoint travelling with each size, and an index
list moves both while a sorted size list would have lost the
correspondence.

## What atlas and sector would take from here, and what they keep

This package is cut out of [`orbit/atlas`](../atlas) — a tiled map
renderer — with [`orbit/sector`](../sector), a strategy game on the same
engine, as its second reader. Neither has been changed by this
interface; what follows is the measurement, so the implementation lane
knows what it is aiming at.

**What they would take:**

| what | where it is now | what replaces it |
| --- | --- | --- |
| even-odd point-in-ring | `atlas/overlay.nv` `point_in`, 20 lines | `geompoly.contains(p, pt, GeomEvenOdd)` |
| ring centroid | `atlas/overlay.nv` `centroid_x` / `centroid_y` | `geompoly.centroid` — and it is a **fix**, not a move: those two average the VERTICES, so a boundary traced with a hundred points along one coast and three across the other pulls its label toward the detailed side. `geompoly.centroid` weights by area and does not. |
| segment length and normal | `atlas/vecmap.nv` `seg_len`, `seg_nx`, `seg_ny` | `geompoint.length`, `geompoint.perpendicular` on a `between` |
| the visible world rectangle | `atlas/camera.nv` `half_w_world` / `half_h_world` feeding `tiles.visible_set` | a `GeomRectF` and `geomrect.intersection` against the world bounds |
| the UV sub-rectangle | `atlas/tiles.nv` `UvRect` + `uv_in_ancestor` | `GeomRectF` and `geompack.uv_of`'s half-open division |
| the glyph atlas grid | `atlas/text.nv` `atlas_cols` / `atlas_rows` + the cell address | `geompack` — and the same fix: a variable-width font stops paying for the widest glyph in every cell |
| ring storage | `sector/geodata.nv` `Buildings.ring_off` / `ring_len` / `xs` / `ys`, mirroring `atlas/overlay.nv` | `[GeomPoly]`, which is one flat buffer per ring instead of four parallel lists and an offset table |
| distance between units | `sector/sim.nv`'s inline `math.sqrt(dx * dx + dy * dy)` | `geompoint.distance_sq` in the comparisons, `distance` where the number is shown |

**What they keep**, and the line is worth drawing because it is what
makes this package `core`:

- **The camera.** `atlas/camera.nv` is a projection with a tilt, a
  perspective divide and a smoothing time constant, and it writes a 4x4
  MVP matrix into GPU memory with `[mutate]`. A 2-D affine transform is
  not that, and pretending otherwise would drag a `host` effect into
  this package.
- **The geography.** `atlas/geo.nv` is Web Mercator — longitude and
  latitude onto a square world. That is a projection, not geometry, and
  it belongs with the tiles.
- **The tile pyramid.** `atlas/tiles.nv`'s `pack`/`pk_z`/`pk_x`/`pk_y`
  is an encoding for getting an id across a channel, and `visible_set`
  is about a level-of-detail policy. Neither has a rectangle in it that
  this package would improve.
- **The cache, the tile store and the engine.** Every one of them
  touches the GPU, the disk or a worker process.
- **`sector/influence.nv` and `sector/sim.nv`.** Game rules. They use
  geometry; they are not geometry.

The split is roughly 300 lines out of atlas's 3,700 and 60 out of
sector's 4,500 — small, and that is the honest number. The value is not
the line count: it is that the centroid gets fixed once, the UV
half-open rule is written once, and `plot-nv` and `svg-nv` get the same
rectangle algebra the map renderer uses.

## Related

- [`svg-nv`](https://github.com/novolang/svg-nv) — vector documents over
  these points and transforms
- [`plot-nv`](https://github.com/novolang/plot-nv) — charts laid out
  with these rectangles
- [Publishing a package to Orbit](https://novo-lang.org/publishing) —
  the layer rules this package is held to
