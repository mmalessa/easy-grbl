import 'dart:ui';
import 'package:path_drawing/path_drawing.dart';
import '../models/svg_document.dart';
import '../models/svg_node.dart';
import '../models/operation_type.dart';
import 'affine.dart';

/// Pre-baked toolpath for canvas rendering. All coordinates are in SVG space.
class ToolpathData {
  /// Rapid (laser-off) moves — G0 transitions between contours.
  final Path rapidPath;

  /// Laser-on feed moves, keyed by operation colour.
  final Map<Color, Path> feeds;

  const ToolpathData({required this.rapidPath, required this.feeds});

  bool get isEmpty => feeds.isEmpty;
}

/// Computes a [ToolpathData] for [doc] in SVG coordinate space (no Y-flip).
/// Returns null when there are no active paths.
ToolpathData? computeToolpath(SvgDocument doc) {
  final vb = doc.viewBox;
  final rapidPath = Path();
  final feedMap = <Color, Path>{};
  bool hasAny = false;

  // Machine origin (0,0) maps to this SVG position
  final origin = Offset(vb.left, vb.bottom);
  var lastPos = origin;

  void addContour(List<Offset> svgPts, Color color) {
    if (svgPts.isEmpty) return;
    hasAny = true;
    // Rapid move to start of this contour
    rapidPath.moveTo(lastPos.dx, lastPos.dy);
    rapidPath.lineTo(svgPts.first.dx, svgPts.first.dy);
    // Feed (laser on)
    final p = feedMap.putIfAbsent(color, Path.new);
    p.moveTo(svgPts.first.dx, svgPts.first.dy);
    for (final pt in svgPts.skip(1)) {
      p.lineTo(pt.dx, pt.dy);
    }
    lastPos = svgPts.last;
  }

  _walkNodes(doc.roots, SvgAffine.identity, true, null, addContour);

  if (!hasAny) return null;

  // Final rapid back to origin
  rapidPath.moveTo(lastPos.dx, lastPos.dy);
  rapidPath.lineTo(origin.dx, origin.dy);

  return ToolpathData(rapidPath: rapidPath, feeds: feedMap);
}

// Sample spacing in mm — coarser than G-code generation for rendering speed.
const _step = 0.5;

void _walkNodes(
  List<SvgNode> nodes,
  SvgAffine parentM,
  bool parentEnabled,
  OperationType? inheritedOp,
  void Function(List<Offset>, Color) addContour,
) {
  for (final node in nodes) {
    if (!node.enabled || !parentEnabled) continue;
    final m = parentM.multiply(SvgAffine.fromSvgString(node.transform));
    final ownOp = node.settings.operationType;
    final eff = ownOp != OperationType.skip ? ownOp : inheritedOp;
    if (node.pathData != null && eff != null && eff != OperationType.skip) {
      for (var pass = 0; pass < node.settings.passes; pass++) {
        _samplePath(node.pathData!, m, eff.color, addContour);
      }
    }
    _walkNodes(node.children, m, node.enabled, eff, addContour);
  }
}

void _samplePath(
  String pathData,
  SvgAffine xform,
  Color color,
  void Function(List<Offset>, Color) addContour,
) {
  final Path path;
  try {
    path = parseSvgPathData(pathData);
  } catch (_) {
    return;
  }
  for (final metric in path.computeMetrics()) {
    if (metric.length < 0.001) continue;
    final pts = <Offset>[];
    for (var d = 0.0; d <= metric.length; d += _step) {
      final t = metric.getTangentForOffset(d);
      if (t != null) {
        final tp = xform.apply(t.position);
        if (pts.isEmpty || (tp - pts.last).distanceSquared > 0.04) pts.add(tp);
      }
    }
    final endT = metric.getTangentForOffset(metric.length);
    if (endT != null) {
      final tp = xform.apply(endT.position);
      if (pts.isEmpty || (tp - pts.last).distanceSquared > 0.04) pts.add(tp);
    }
    if (pts.length >= 2) addContour(pts, color);
  }
}
