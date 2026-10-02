import 'dart:ui';
import '../models/layer_settings.dart';

const double _sampleStep = 0.1; // mm per sample along contour edges

/// Computes fill line segments in SVG space using scanline intersection.
/// Returns pairs (start, end) in alternating directions (boustrophedon).
/// Handles compound paths (e.g. shapes with holes) correctly via even-odd rule.
///
/// [inset] shrinks each line segment by this amount on both ends and narrows
/// the scanline band accordingly — use spotSize/2 to avoid double-burning
/// when an outline pass is also generated.
List<(Offset, Offset)> computeFillLines(
  Path path,
  FillDirection direction,
  double linesPerMm, {
  double inset = 0.0,
}) {
  final bounds = path.getBounds();
  if (bounds.isEmpty) return const [];

  final step = 1.0 / linesPerMm;
  final result = <(Offset, Offset)>[];

  // Build one closed polygon per contour — do NOT connect contours to each
  // other.  A naïve single boundary list would create spurious segments
  // between subpaths (e.g. the closing point of an outer circle joined to
  // the first point of the inner hole), producing wrong crossings and
  // filling areas that should remain empty.
  final contours = <List<Offset>>[];
  for (final metric in path.computeMetrics()) {
    if (metric.length < 0.001) continue;
    final pts = <Offset>[];
    final start = metric.getTangentForOffset(0)?.position;
    var d = 0.0;
    while (d <= metric.length) {
      final t = metric.getTangentForOffset(d);
      if (t != null) pts.add(t.position);
      d += _sampleStep;
    }
    if (start != null) pts.add(start); // close back to start
    if (pts.length >= 2) contours.add(pts);
  }
  if (contours.isEmpty) return const [];

  if (direction == FillDirection.horizontal) {
    var leftToRight = true;
    var y = bounds.top + inset.clamp(0, double.infinity);
    if (y < bounds.top + step * 0.5) y = bounds.top + step * 0.5;
    while (y < bounds.bottom - inset) {
      final xs = _crossingsX(contours, y);
      for (var i = 0; i + 1 < xs.length; i += 2) {
        final a = xs[i] + inset;
        final b = xs[i + 1] - inset;
        if (a >= b) continue;
        result.add(leftToRight
            ? (Offset(a, y), Offset(b, y))
            : (Offset(b, y), Offset(a, y)));
        leftToRight = !leftToRight;
      }
      y += step;
    }
  } else {
    var topToBottom = true;
    var x = bounds.left + inset.clamp(0, double.infinity);
    if (x < bounds.left + step * 0.5) x = bounds.left + step * 0.5;
    while (x < bounds.right - inset) {
      final ys = _crossingsY(contours, x);
      for (var i = 0; i + 1 < ys.length; i += 2) {
        final a = ys[i] + inset;
        final b = ys[i + 1] - inset;
        if (a >= b) continue;
        result.add(topToBottom
            ? (Offset(x, a), Offset(x, b))
            : (Offset(x, b), Offset(x, a)));
        topToBottom = !topToBottom;
      }
      x += step;
    }
  }

  return result;
}

/// Finds all X intersections of a horizontal scanline at [y] with [contours].
List<double> _crossingsX(List<List<Offset>> contours, double y) {
  final xs = <double>[];
  for (final boundary in contours) {
    for (var i = 0; i < boundary.length - 1; i++) {
      final p1 = boundary[i], p2 = boundary[i + 1];
      if ((p1.dy <= y && p2.dy > y) || (p2.dy <= y && p1.dy > y)) {
        final t = (y - p1.dy) / (p2.dy - p1.dy);
        xs.add(p1.dx + t * (p2.dx - p1.dx));
      }
    }
  }
  xs.sort();
  return xs;
}

/// Finds all Y intersections of a vertical scanline at [x] with [contours].
List<double> _crossingsY(List<List<Offset>> contours, double x) {
  final ys = <double>[];
  for (final boundary in contours) {
    for (var i = 0; i < boundary.length - 1; i++) {
      final p1 = boundary[i], p2 = boundary[i + 1];
      if ((p1.dx <= x && p2.dx > x) || (p2.dx <= x && p1.dx > x)) {
        final t = (x - p1.dx) / (p2.dx - p1.dx);
        ys.add(p1.dy + t * (p2.dy - p1.dy));
      }
    }
  }
  ys.sort();
  return ys;
}
