# geometry-nv

Two-dimensional geometry as arithmetic: points, vectors and sizes, axis-aligned
rectangles, affine transforms, polygons, and a packer that fits rectangles into
a bin. The types and the transform algebra follow
[euclid](https://github.com/servo/euclid), and the polygon predicates follow
the subset of [shapely](https://shapely.readthedocs.io/) a drawing program
uses. Three other packages on the registry are built on it:
[svg-nv](https://novo-lang.org/packages/svg-nv),
[font-nv](https://novo-lang.org/packages/font-nv) and
[raster-nv](https://novo-lang.org/packages/raster-nv).

## What it is

A **point** is a position. A **vector** is a displacement from one position to
another. A **size** is an extent with no position at all. They are three
separate types here, because an affine transform treats them differently: a
translation moves a point and leaves a vector unchanged, and a size has no
place in the plane to be moved from.

Each of those comes in two flavours. The `F` flavour holds `Float`
coordinates, for a position in continuous space. The `I` flavour holds `Int`
coordinates, for a pixel, a cell or a texel. The conversions between them are
named for what they do: `to_int_floor` is the pixel a position falls inside,
and `to_int_round` is the nearest pixel.

A **rectangle** here is axis-aligned and stored as two corners, a low one and
a high one. That is euclid's `Box2D` rather than its `Rect`, which holds an
origin and a size. The corner form is what the algebra wants: a union is a
minimum and a maximum per axis, an intersection is a maximum and a minimum,
and containment is four comparisons. A rectangle whose low corner is not below
its high corner on some axis is **empty**: it encloses nothing.

An **affine transform** of the plane is a 3 by 3 matrix whose bottom row is
always zero, zero, one. `GeomXform` stores the six numbers that vary, in the
order
[SVG's `matrix(a b c d e f)`](https://www.w3.org/TR/SVG11/coords.html#TransformAttribute)
names them, which is the same order PostScript, Cairo and euclid use.

A **polygon** here is one closed ring of vertices in order. The closing edge
is implicit: the last vertex connects back to the first. The **winding** of a
ring is which way it turns. A **fill rule** decides which side of a ring is
inside, and there are two: the even-odd rule counts crossings, and the
non-zero rule counts them with their direction.

**Packing** is fitting many small rectangles into one big one, which is what a
glyph atlas, a sprite sheet and a texture page are. The algorithm here is
**shelf packing**: the bin is divided into horizontal bands, and each
rectangle goes on the first band tall enough to take it.

| Quantity | Value |
| --- | --- |
| Numbers in a `GeomPointF` or a `GeomVecF` | 2 |
| Numbers in a `GeomRectF` | 4, as two corners |
| Numbers in a `GeomXform` | 6 |
| Numbers a shelf carries | 3 |
| Vertices the smallest polygon may have | 3 |
| Fill rules | 2 |
| Modules that build for a microcontroller | 3 of 7 |

## Install

```
novo pkg add geometry-nv
```

## Example

```novo
use geompoint
use geomrect
use geomxform
use geomtext

fn main() [io]
    // The pixel rectangle a chart is drawn into: a 640 by 480 canvas with
    // 40 taken off the left for labels and 30 off the bottom for the axis.
    let area = geomrect.inset(geomrect.of_xywh(0.0, 0.0, 640.0, 480.0),
                              40.0, 10.0, 10.0, 30.0)

    // The same rectangle with its vertical axis running upwards, which is
    // the direction data is measured in and a screen's pixels are not.
    let flipped = geomrect.of_xywh(area.min.x, area.max.y,
                                   geomrect.width(area),
                                   0.0 - geomrect.height(area))

    // The transform that carries data coordinates onto those pixels.
    let to_pixels = geomxform.mapping(geomrect.of_xywh(0.0, 0.0, 100.0, 1.0),
                                      flipped)

    // Where the data point (50, 0.5) lands on the canvas: (335, 230).
    println(geomtext.format_point(geomxform.apply_point(to_pixels,
                                                        geompoint.ptf(50.0, 0.5))))
```

## What the package contains

| Module | Contents |
| --- | --- |
| `geompoint` | Points, vectors and sizes in both flavours, the vector algebra over them, the squared length and distance, interpolation, and the conversions between the two flavours. |
| `geomrect` | Rectangles in both flavours, the union, intersection and containment algebra, the inset, inflate and translate operations, the bounding box of a list of points, and the conversions to and from the integer grid. |
| `geomxform` | Affine transforms: the constructors, composition, application to a point, a vector or a rectangle, the determinant, inversion, and the predicates that describe a transform's shape. |
| `geomtrig` | The functions that take a square root or an angle: length, distance, unit vectors, and the rotations. |
| `geomtext` | Points, rectangles and transforms written out as text, the last as SVG's `matrix(a b c d e f)`. |
| `geompoly` | One closed ring: its area, perimeter, winding, centroid, bounds and convexity, containment under both fill rules, simplification, and the two segment functions the containment test is built on. It also holds the two functions whose answer is a list of points: a rectangle's corners and a list sent through a transform. |
| `geompack` | A bin being packed: placing one rectangle or many, the two orderings, the counts and the occupancy, the texture coordinates of a placement, and the smallest square page that would hold the result. |

## How to choose an entry point

**`geomxform.mapping` is the way in for anything that draws.** Given the
rectangle the data lives in and the rectangle the pixels live in, it answers
the transform between them. A vertical flip is not a special case: it is what
a destination rectangle with a negative height means.

**`geomxform.compose` is the way in for a transform built in stages.**
`compose(first, second)` applies `first` and then `second`, reading left to
right.

**`geomrect.intersection` is the way in for clipping.** It answers a rectangle
that may enclose nothing, and `is_empty` is the question about it.

**`geompack.place` is the way in for an atlas built as it is read.** It takes
one rectangle and answers a new bin, so a caller streaming glyphs out of a font
never holds them all. Each call copies the placements made so far.
`place_all` is the whole-list form, and copies once.

**`geompoly.contains` is the way in for hit testing.** It takes the fill rule,
because the two rules disagree on a self-intersecting ring.

## The rules a user needs

1. **A transform applies its translation to a point and not to a vector.**
   `apply_point` moves a position. `apply_vec` moves a displacement, and a
   displacement does not care where the origin is. Handing a vector to
   `apply_point` gives an answer that is wrong by the translation.
2. **`compose(first, second)` applies `first` and then `second`.** The
   convention is a row vector multiplied on the left of the matrix. The
   column-vector convention taught in linear algebra would make the same call
   mean "second, then first". There is no second spelling of this function.
3. **An empty rectangle is a value, not an error.** `intersection` answers a
   rectangle whose low corner is not below its high corner, and `is_empty` says
   so. A clip coming back empty is the ordinary outcome, not a failure. Every
   function here is defined on an empty rectangle: its union with another
   rectangle is the other one, its intersection with anything is empty,
   `contains_point` is false, and `center` answers the origin.
4. **`empty()` is the canonical empty rectangle and `normalize` produces it.**
   Its low corner is at positive infinity and its high corner at negative
   infinity, so it holds no point, and a bounding box folded with `extend`
   from it starts at the first point. Two empty rectangles from different clips
   hold different coordinates until they are normalized. Nothing normalizes for
   the caller.
5. **Containment is half-open.** A point on a low edge is inside, and a point
   on a high edge is outside. That is what makes two rectangles sharing an
   edge cover each pixel once.
6. **`invert` is total and `is_invertible` is the question.** A singular
   transform inverts to the identity, which means a caller who skipped the
   check sees untransformed coordinates rather than a matrix that turns every
   later point into a NaN and draws nothing.
7. **A polygon's closing edge is implicit.** Three vertices make a triangle.
   Repeating the first vertex at the end adds a zero-length edge, which
   changes no answer here and costs a step in every walk.
8. **`geompoly.centroid` is the centre of the ring's area.** It is not the
   average of the vertices. A boundary traced with a hundred points along one
   side and three along another has a vertex average pulled toward the
   detailed side, and an area centroid that is not.
9. **`signed_area` is negative for a clockwise ring and `area` never is.**
   `winding` is the same fact as an enum, and `GeomDegenerate` is a ring whose
   signed area is zero.
10. **The caller orders the input to the packer.** Decreasing height is the
    half that makes shelf packing good, and it is not done inside `place`.
    `order_by_height` answers a permutation, a list of indices, rather than a
    sorted list. A caller packing glyphs has a codepoint travelling with each
    size, and an index list moves both.
11. **A failed placement is recorded rather than refused.** `place` always
    answers a bin. `GeomPlacement.ok` says whether the rectangle fit, and
    `fitted_count` against `placed_count` is the summary.
12. **`geompack.uv_of` divides on the half-open rule.** A rectangle filling
    the whole bin runs from `(0, 0)` to `(1, 1)`.
13. **Comparing two of these values with `==` is rejected, and so is
    interpolating one into a string.** SPEC section 14.5 keeps the comparison
    operators off an unboxed struct. `geompoint.near` and `geomxform.near`
    take an epsilon, and `geomtext` writes a value out, a transform in SVG's
    own spelling.
14. **Angles are in radians, measured from positive x toward positive y.**
    `geomtrig.angle_of` answers in `(-pi, pi]`, and `geomtrig.from_angle`,
    `rotation` and `rotation_about` take the same measure.
15. **`length_sq` and `distance_sq` take no square root.** They are the forms
    a comparison wants, and they build for a microcontroller.
    `geomtrig.length` and `geomtrig.distance` are for the number a reader
    sees.
16. **A function that can be asked an impossible question answers a value.**
    `geompoly.vertex_at` answers the origin for an index out of range,
    `geompack.placement_at` answers a placement with `ok` false, and
    `geomrect.center` answers the origin for an empty rectangle. Only
    `geompoly.of_points` and `geompoly.regular` answer a `Result`, and
    `GeomFault` is why.
17. **Converting to the grid stops the program on a coordinate that is not a
    number or is outside the range of `Int`.** `to_int_floor`,
    `to_int_round`, `to_int_outer` and `to_int_inner` convert with `as Int`,
    which SPEC section 13.3 defines that way.

## Running on a microcontroller

novo-lang lets a package state which of its modules can run on a device with
no heap allocator, and the compiler checks that claim on every build. Here the
claim covers `geompoint`, `geomrect` and `geomxform`: the point, rectangle and
transform arithmetic. Every function in them is `@tier(embedded)`, so an
allocation or a call into the C maths library written there is refused where
it is written.

```bash
novo build --target=nrf52-qemu tests/embedded_probe.nv
```

The probe is firmware that maps a viewport onto a 128 by 64 display, clips a
widget rectangle against the screen, measures a vector and undoes a scale. It
boots under QEMU's `mps2-an386` machine and prints `PASS: geometry-embedded`
when every answer is exact. `tests/alloc_scan.sh` reads the emitted LLVM of all
three modules and finds no call to the allocator.

The other four modules are outside the claim. `geompoly` and `geompack` hold
lists, and a list is a heap allocation. `geomtrig` calls `sqrt`, `sin`, `cos`
and `atan2`, which a device without a double-precision floating-point unit
takes from the C maths library, and `geomtext` builds text. All four are pure
and have no effects. On a device, `length_sq` and `distance_sq` answer every
comparison, and a rotation whose sine and cosine are known ahead of time is
`geomxform.of_matrix(c, s, -s, c, 0, 0)`.

What makes the claim possible is the unboxed layout. `@value` (SPEC section 14)
lays these structs out with true field widths and passes them in registers, and
a list of them is one flat buffer with no per-element cell and no per-element
reference count (SPEC section 14.6).

## What is not included

- **Unit or space type parameters.** euclid's `Point2D<T, U>` tags a point
  with the space it lives in, so screen coordinates and world coordinates
  cannot be mixed up. A tag would be a type parameter on every type and
  every function here, and the points of this package all live in one
  untagged space.
- **A single generic point type.** `GeomPointF` and `GeomPointI` are written
  out rather than generated from a `GeomPoint<T>`. A Float point is a
  position in a continuous space and an Int point is a pixel, and the
  functions that turn one into the other are where the rounding happens.
- **Polygons with holes, and boolean operations between polygons.** A polygon
  with holes is a list of rings with a fill rule, which is a different type
  with a different containment test and a different area. Adding it later is a
  new type beside this one rather than a change to this one.
- **Skyline and MaxRects packing.** Both pack tighter than shelf, and both are
  worth having when a texture page is the scarce resource. Shelf is here
  because its state is bounded: three integers per shelf, with the number of
  shelves bounded by the bin's height over the shortest rectangle. Skyline
  keeps a segment list whose length grows with the width and the input.
- **A `then` alias for `compose`.** `then` is a reserved word, because it
  separates an inline conditional's branches (SPEC section 1.3).
- **A square root or a rotation by angle on a microcontroller.** Both need the
  C maths library there; see the section above.
- **Three-dimensional geometry, projections and perspective.** A camera with a
  tilt and a perspective divide is not an affine transform of the plane.
- **Curves.** Béziers, arcs and their flattening live in
  [svg-nv](https://novo-lang.org/packages/svg-nv), which is where a path is.

## Related packages

- [svg-nv](https://novo-lang.org/packages/svg-nv) is the SVG document model.
  It takes its points and transforms from here, and
  `geomtext.format_matrix` is the agreed spelling so the two packages cannot
  disagree about argument order.
- [font-nv](https://novo-lang.org/packages/font-nv) reads a font file. A glyph
  outline is expressed in these points, and a glyph atlas is packed with
  `geompack`.
- [raster-nv](https://novo-lang.org/packages/raster-nv) draws shapes into a
  surface. It fills the polygons and strokes the paths this package describes.
- `std.math` in the standard library is the scalar functions underneath:
  square roots, trigonometry and rounding. This package is the two-dimensional
  values built on them.

## Tests

```bash
novo test tests/geometry_tests.nv   # points, vectors, sizes, rectangles, transforms
novo test tests/measure_tests.nv    # lengths, angles, rotations, text forms
novo test tests/shape_tests.nv      # polygons, the list forms, rectangle packing
bash tests/coverage.sh              # line coverage over src/, merged across suites
bash tests/alloc_scan.sh            # no allocation in the three device modules
```

The reference implementations are euclid for the types and the transform
algebra, and shapely for the polygon predicates. Both are permissively
licensed, and both are where the expected values come from. The rectangle
cases follow euclid's `Box2D` semantics and the transform cases follow SVG's
`matrix(a b c d e f)`.

The worked numbers are the unit square, the 3-4-5 triangle and the quarter
turn, so a reviewer can check an expected answer without a calculator. The
packing cases are worked by hand from the shelf rule. Two property tests check
the laws over a few hundred cases drawn from a fixed pseudo-random sequence:
for rectangles, that union and intersection commute, that intersection is
associative, that a union contains both operands and both contain the
intersection, and that a point is in the intersection exactly when it is in
both; for transforms, that `compose` applies its first argument first, that
composition is associative, that determinants multiply, and that a transform
composed with its inverse is the identity. No assertion compares two unboxed
structs with `==`, because the operator rejects one: each reads a field or
calls the package's own `near`.

## Licence

Apache-2.0. See `LICENSE`.

<!-- docs/writing-a-readme.md is the style guide for this page. -->
