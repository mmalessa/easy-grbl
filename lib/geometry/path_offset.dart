import 'dart:ui';
import 'package:clipper2/clipper2.dart';

/// Offsets closed cut-path contours by a tool-radius amount (kerf
/// compensation), backed by the clipper2 polygon-offsetting engine — a
/// hand-rolled per-vertex normal offset would self-intersect on concave
/// corners, which is a correctness problem for a tool that removes real
/// material.
class PathOffset {
  static const double _scale = 1000.0; // mm -> clipper integer micro-units
  static const double _closeToleranceMm = 0.01;

  static bool isClosed(List<Offset> pts) =>
      pts.length >= 3 && (pts.first - pts.last).distance < _closeToleranceMm;

  /// Offsets a closed contour by [deltaMm] (positive grows the shape
  /// outward, negative shrinks it inward — clipper2's ClipperOffset
  /// normalizes this internally regardless of the input contour's winding
  /// direction). Returns [pts] unchanged if the offset is negligible, the
  /// contour isn't closed (open paths have no "inside"), or the offset
  /// consumes the whole shape (falls back rather than vanishing the cut).
  static List<Offset> offsetClosedContour(List<Offset> pts, double deltaMm) {
    if (deltaMm.abs() < 1e-6 || !isClosed(pts)) return pts;

    final coords = <double>[];
    for (final p in pts) {
      coords.add(p.dx);
      coords.add(p.dy);
    }
    final path64 = PathDExt.from(coords).scaledPath64(_scale);

    final offsetter = ClipperOffset()
      ..addPath(path64, joinType: JoinType.round, endType: EndType.polygon);
    final result = offsetter.execute(delta: deltaMm * _scale);
    if (result.isEmpty) return pts;

    result.sort((a, b) => b.area.abs().compareTo(a.area.abs()));
    final out = result.first
        .scaledPathD(1 / _scale)
        .map((p) => Offset(p.x, p.y))
        .toList();
    if (out.isNotEmpty &&
        (out.first - out.last).distance > _closeToleranceMm) {
      out.add(out.first);
    }
    return out;
  }

  /// Shrinks the filled region bounded by [contours] (even-odd, like an SVG
  /// fill) by [deltaMm]: outer edges move inward and holes grow, so a tool of
  /// radius [deltaMm] running on the result never leaves the region. Every
  /// returned contour is closed (first point repeated last). Returns an empty
  /// list when the region is narrower than 2×[deltaMm] everywhere.
  static List<List<Offset>> insetFilledRegion(
      List<List<Offset>> contours, double deltaMm) {
    final paths = <Path64>[
      for (final c in contours)
        if (c.length >= 3)
          PathDExt.from([for (final p in c) ...[p.dx, p.dy]])
              .scaledPath64(_scale),
    ];
    if (paths.isEmpty) return const [];

    // Normalise to non-overlapping polygons with holes oriented opposite to
    // their outers — ClipperOffset tells holes apart by orientation only.
    final region = Clipper.union(subject: paths, fillRule: FillRule.evenOdd);
    final offsetter = ClipperOffset()
      ..addPaths(region, joinType: JoinType.round, endType: EndType.polygon);
    final result = offsetter.execute(delta: -deltaMm * _scale);

    return [
      for (final p in result)
        if (p.length >= 3)
          [
            for (final q in p.scaledPathD(1 / _scale)) Offset(q.x, q.y),
            Offset(p.first.x / _scale, p.first.y / _scale),
          ],
    ];
  }
}
