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

**Status: NOT IMPLEMENTED — interface only.** Every function is declared with
its full signature, but every body is a `todo()` that panics when called. The
package is published so its design can be reviewed and depended on before it
is implemented. Version 0.1.0 will be the first working release.

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
and containment is four comparisons.

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
| Modules that build for a microcontroller | 3 of 5 |

## Install

```
novo pkg add geometry-nv
```

## Example

```novo
use geompoint
use geomrect
use geomxform

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

    // Where the data point (50, 0.5) lands on the canvas.
    println(geompoint.format(geomxform.apply_point(to_pixels,
                                                   geompoint.ptf(50.0, 0.5))))
```

Build and test with `novo pkg build` and `novo test`. Today `novo test` fails
on purpose: every test reaches a `not implemented: geometry-nv.<module>.<fn>`
panic. The tests are the specification the implementation will have to
satisfy.

## What the package contains

| Module | Contents |
| --- | --- |
| `geompoint` | Points, vectors and sizes in both flavours, the vector algebra over them, the distance and interpolation functions, and the conversions between the two flavours. |
| `geomrect` | Rectangles in both flavours, the union, intersection and containment algebra, the inset, inflate and translate operations, and the conversions to and from the integer grid. |
| `geomxform` | Affine transforms: the constructors, composition, application to a point, a vector, a rectangle or a list, the determinant, inversion, and the predicates that describe a transform's shape. |
| `geompoly` | One closed ring: its area, perimeter, winding, centroid, bounds and convexity, containment under both fill rules, simplification, and the two segment functions the containment test is built on. |
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
one rectangle and answers the bin, so a caller streaming glyphs out of a font
never holds them all. `place_all` is the whole-list form.

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
   rectangle whose low corner is above its high corner, and `is_empty` says
   so. A clip coming back empty is the ordinary outcome, not a failure. Every
   function here is defined on an empty rectangle: its union with another
   rectangle is the other one, its intersection with anything is empty, and
   `contains_point` is false.
4. **`empty()` is the canonical empty rectangle and `normalize` produces it.**
   Two empty rectangles from different clips hold different coordinates until
   one of them is normalized. Nothing normalizes for the caller, because it
   costs four comparisons and most callers only ask `is_empty`.
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
    take an epsilon, `geompoint.format` and `geomrect.format` write a value
    out, and `geomxform.format_matrix` writes SVG's own spelling. Comparing
    two floats for exact equality was the wrong test anyway.
14. **Angles are in radians, measured from positive x toward positive y.**
    `geompoint.angle_of`, `from_angle`, `geomxform.rotation` and
    `rotation_about` all use them.
15. **`length_sq` and `distance_sq` take no square root.** They are the forms
    a comparison wants. `length` and `distance` are for the number a reader
    sees.
16. **A function that can be asked an impossible question answers a value.**
    `geompoly.vertex_at` answers the origin for an index out of range,
    `geompack.placement_at` answers a placement with `ok` false, and
    `geomrect.center` answers the origin for an empty rectangle. Only
    `geompoly.of_points` and `geompoly.regular` answer a `Result`, and
    `GeomFault` is why.

## Running on a microcontroller

novo-lang lets a package state which of its modules can run on a device with
no heap allocator, and the compiler checks that claim on every build. Here the
claim covers `geompoint`, `geomrect` and `geomxform`: the point, rectangle and
transform arithmetic.

```bash
novo build --target=nrf52-qemu tests/embedded_probe.nv
```

That command builds today, and it is the whole of the claim. The probe is
firmware that maps a viewport onto a 128 by 64 display, clips a widget
rectangle against the screen, and measures a vector. Three unboxed structs
cross four call boundaries in it and none of them is a pointer.

`geompoly` and `geompack` are outside the claim. A ring's vertices and a bin's
shelves are lists, and a list is a heap allocation. Both modules are pure and
both have no effects, but neither is the part that runs in firmware.

What makes the claim possible is the unboxed layout. `@value` (SPEC section 14)
lays these structs out with true field widths and passes them in registers, and
a list of them is one flat buffer with no per-element cell and no per-element
reference count (SPEC section 14.6). Boxed, every point would be a cell with a
reference count and the probe would not link.

## What is not included

- **Unit or space type parameters.** euclid's `Point2D<T, U>` tags a point
  with the space it lives in, so screen coordinates and world coordinates
  cannot be mixed up. A generic function whose return type applies a generic
  head is not emitted for a call from another module on this toolchain, which
  would make every tagged type unreachable across a module boundary.
- **A single generic point type.** The same emission limit is why
  `GeomPointF` and `GeomPointI` are written out rather than generated from a
  `GeomPoint<T>`.
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
- **Three-dimensional geometry, projections and perspective.** A camera with a
  tilt and a perspective divide is not an affine transform of the plane.
- **Curves.** Béziers, arcs and their flattening live in
  [svg-nv](https://novo-lang.org/packages/svg-nv), which is where a path is.

## Related packages

- [svg-nv](https://novo-lang.org/packages/svg-nv) is the SVG document model.
  It takes its points and transforms from here, and
  `geomxform.format_matrix` is the agreed spelling so the two packages cannot
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
novo test tests/shape_tests.nv      # polygons and rectangle packing
```

The reference implementations are euclid for the types and the transform
algebra, and shapely for the polygon predicates. Both are permissively
licensed, and both are where the expected values come from. The rectangle
cases follow euclid's `Box2D` semantics and the transform cases follow SVG's
`matrix(a b c d e f)`.

The worked numbers are the unit square, the 3-4-5 triangle and the quarter
turn, so a reviewer can check an expected answer without a calculator. The
packing cases are worked by hand from the shelf rule. No assertion compares two
unboxed structs with `==`, because the operator rejects one: each reads a field
or calls the package's own `near`.

The two files split on what the two halves of the package hold. Everything in
`geometry_tests.nv` is unboxed arithmetic that a device runs. Everything in
`shape_tests.nv` holds a list.

The tests compile today and fail at run, each on the
`not implemented: geometry-nv.<module>.<fn>` panic that is its body. That is
the expected state of an interface release. They turn green one at a time as
bodies land. `novo test --isolate tests/<file>` prints one verdict per test.

## Implementation status

| Item | Implemented |
| --- | --- |
| The six `geompoint` types, the two `geomrect` types, `GeomXform`, `GeomShelf`, `GeomPlacement` | the types are declared; nothing constructs one |
| `GeomPoly`, `GeomBin`, `GeomWinding`, `GeomFillRule`, `GeomFault` | the types are declared; nothing constructs one |
| `geompoint.ptf`, `.pti`, `.vecf`, `.veci`, `.sizef`, `.sizei`, `.origin`, `.zero_vec` | no |
| `geompoint.offset`, `.between`, `.add`, `.sub`, `.scale`, `.negate` | no |
| `geompoint.dot`, `.cross`, `.length`, `.length_sq`, `.normalize`, `.perpendicular` | no |
| `geompoint.angle_of`, `.from_angle`, `.distance`, `.distance_sq`, `.lerp`, `.midpoint`, `.near` | no |
| `geompoint.to_float`, `.to_int_floor`, `.to_int_round`, `.vec_to_float`, `.size_to_float` | no |
| `geompoint.area_of`, `.area_of_i`, `.size_is_empty`, `.size_is_empty_i`, `.format` | no |
| `geomrect.of_corners`, `.of_origin_size`, `.of_xywh`, `.of_corners_i`, `.of_xywh_i`, `.spanning` | no |
| `geomrect.empty`, `.empty_i`, `.is_empty`, `.is_empty_i`, `.normalize` | no |
| `geomrect.width`, `.height`, `.size_of`, `.area`, `.center`, `.width_i`, `.height_i`, `.area_i` | no |
| `geomrect.contains_point`, `.contains_rect`, `.intersects`, `.intersection`, `.union` | no |
| `geomrect.contains_point_i`, `.contains_rect_i`, `.intersection_i`, `.union_i` | no |
| `geomrect.extend`, `.bounding`, `.translate`, `.inflate`, `.inset`, `.clamp_point`, `.corners` | no |
| `geomrect.relative`, `.absolute`, `.to_int_outer`, `.to_int_inner`, `.to_float_rect`, `.format` | no |
| `geomxform.identity`, `.of_matrix`, `.translation`, `.scaling`, `.rotation` | no |
| `geomxform.rotation_about`, `.scaling_about`, `.shear`, `.mapping`, `.compose` | no |
| `geomxform.translated`, `.scaled`, `.rotated` | no |
| `geomxform.apply_point`, `.apply_vec`, `.apply_rect`, `.apply_points` | no |
| `geomxform.determinant`, `.is_invertible`, `.invert` | no |
| `geomxform.is_identity`, `.is_translation`, `.is_axis_aligned`, `.near`, `.format_matrix` | no |
| `geompoly.of_points`, `.of_points_unchecked`, `.empty`, `.of_rect`, `.regular` | no |
| `geompoly.vertex_count`, `.points_of`, `.vertex_at`, `.bounds` | no |
| `geompoly.signed_area`, `.area`, `.perimeter`, `.winding`, `.oriented`, `.reversed`, `.centroid` | no |
| `geompoly.contains`, `.is_convex`, `.translate`, `.simplify` | no |
| `geompoly.distance_to_edge`, `.closest_on_segment`, `.segments_cross` | no |
| `geompack.bin`, `.place`, `.place_all`, `.reset`, `.would_fit` | no |
| `geompack.order_by_height`, `.order_by_area` | no |
| `geompack.last_placement`, `.placements`, `.placement_at`, `.placed_count`, `.fitted_count` | no |
| `geompack.shelf_count`, `.used_area`, `.free_area`, `.occupancy`, `.used_bounds` | no |
| `geompack.square_page_size`, `.uv_of` | no |

## Licence

Apache-2.0. See `LICENSE`.

<!-- docs/writing-a-readme.md is the style guide for this page. -->
