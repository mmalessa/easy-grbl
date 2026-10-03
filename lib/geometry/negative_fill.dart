import 'dart:ui';
import 'package:path_drawing/path_drawing.dart';
import '../models/layer_settings.dart';
import '../models/svg_node.dart';
import 'affine.dart';
import 'contour_sampler.dart';
import 'fill_lines.dart';
import 'fill_toolpath.dart';
import 'path_offset.dart';

const double _sampleStep = 0.1; // mm per sample along the objects' edges

/// The objects a negative fill of [group] must never touch, as paths in the
/// same space as [groupTransform] (the group's accumulated transform).
///
/// Rule: every visible path in the group's subtree, whatever its own
/// operation (a child set to e.g. Cut still blocks the fill and is burned
/// separately). Kept in this one function so the rule is easy to change.
List<Path> negativeFillObstacles(SvgNode group, SvgAffine groupTransform) {
  final out = <Path>[];
  void visit(SvgNode node, SvgAffine parent) {
    if (!node.enabled) return;
    final t = parent.multiply(SvgAffine.fromSvgString(node.transform));
    final data = node.pathData;
    if (data != null) {
      try {
        out.add(parseSvgPathData(data).transform(t.toFloat64()));
      } catch (_) {}
    }
    for (final c in node.children) {
      visit(c, t);
    }
  }

  for (final c in group.children) {
    visit(c, groupTransform);
  }
  return out;
}

/// Negative-fill toolpath: hatch (and optional outline) covering [area]
/// outside every one of [obstacles], burned with a spot of [spotDiameter].
/// The spot centre stays half a spot away from each obstacle and inside
/// [area], so the burn reaches the obstacles' edges but never enters them.
/// Gaps narrower than the spot stay unburned — there is no edge fallback as
/// in [computeFillToolpath], since that would burn onto an obstacle.
FillToolpath computeNegativeFillToolpath(
  Rect area,
  List<Path> obstacles, {
  required FillDirection direction,
  required double linesPerMm,
  required double spotDiameter,
  required bool outline,
}) {
  final region = PathOffset.regionAroundObjects(
    area,
    [
      for (final p in obstacles)
        samplePathContours(p, step: _sampleStep, minDistSq: 1e-6),
    ],
    spotDiameter / 2,
  );
  if (region.isEmpty) return const FillToolpath(lines: [], outline: []);

  final regionPath = Path()..fillType = PathFillType.evenOdd;
  for (final c in region) {
    regionPath.addPolygon(c, true);
  }
  return FillToolpath(
    lines: computeFillLines(regionPath, direction, linesPerMm),
    outline: outline ? region : const [],
  );
}
