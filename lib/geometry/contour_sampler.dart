import 'dart:ui';
import 'package:path_drawing/path_drawing.dart';

/// Samples every contour of [pathData] every [step] mm (plus its end point),
/// maps each sample through [map] and drops a point when it is within
/// sqrt([minDistSq]) of the previous kept one. Contours shorter than
/// 0.001 mm or with fewer than two kept points are skipped; unparseable path
/// data yields no contours.
List<List<Offset>> sampleContours(
  String pathData, {
  required double step,
  required double minDistSq,
  required Offset Function(Offset) map,
}) {
  final Path path;
  try {
    path = parseSvgPathData(pathData);
  } catch (_) {
    return const [];
  }
  return samplePathContours(path, step: step, minDistSq: minDistSq, map: map);
}

/// [sampleContours] for an already-parsed [path].
List<List<Offset>> samplePathContours(
  Path path, {
  required double step,
  required double minDistSq,
  Offset Function(Offset) map = _identity,
}) {
  final contours = <List<Offset>>[];
  for (final metric in path.computeMetrics()) {
    if (metric.length < 0.001) continue;
    final pts = <Offset>[];
    void add(Tangent? t) {
      if (t == null) return;
      final p = map(t.position);
      if (pts.isEmpty || (p - pts.last).distanceSquared > minDistSq) pts.add(p);
    }

    for (var d = 0.0; d <= metric.length; d += step) {
      add(metric.getTangentForOffset(d));
    }
    add(metric.getTangentForOffset(metric.length));
    if (pts.length >= 2) contours.add(pts);
  }
  return contours;
}

Offset _identity(Offset p) => p;
