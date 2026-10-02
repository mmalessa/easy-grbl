import 'dart:ui';
import 'package:path_drawing/path_drawing.dart';
import '../models/svg_document.dart';
import '../models/operation_type.dart';
import '../models/layer_settings.dart';
import '../machines/gcode/gcode_strategy.dart';
import '../machines/machine_settings.dart';
import '../geometry/affine.dart';
import '../geometry/contour_sampler.dart';
import '../geometry/fill_lines.dart';
import '../geometry/path_offset.dart';
import '../geometry/svg_node_walker.dart';

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
ToolpathData? computeToolpath(SvgDocument doc,
    [MachineSettings machineSettings = const MachineSettings()]) {
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
    rapidPath.moveTo(lastPos.dx, lastPos.dy);
    rapidPath.lineTo(svgPts.first.dx, svgPts.first.dy);
    final p = feedMap.putIfAbsent(color, Path.new);
    p.moveTo(svgPts.first.dx, svgPts.first.dy);
    for (final pt in svgPts.skip(1)) {
      p.lineTo(pt.dx, pt.dy);
    }
    lastPos = svgPts.last;
  }

  final strategy = GcodeStrategy.of(machineSettings);
  walkSvgNodes(doc.roots, (node, transform, effectiveOp, effectiveSettings) {
    if (!isActiveOp(node.pathData, effectiveOp)) return;
    final op = effectiveOp!;
    if (op == OperationType.fill) {
      _sampleFill(node.pathData!, transform, effectiveSettings,
          strategy.fillInset(effectiveSettings), addContour);
    } else {
      final offsetDelta = op == OperationType.cut
          ? strategy.cutOffsetDelta(effectiveSettings)
          : 0.0;
      for (var pass = 0; pass < effectiveSettings.passes; pass++) {
        _samplePath(node.pathData!, transform, op.color, addContour,
            offsetDeltaMm: offsetDelta);
      }
    }
  });

  if (!hasAny) return null;

  rapidPath.moveTo(lastPos.dx, lastPos.dy);
  rapidPath.lineTo(origin.dx, origin.dy);

  return ToolpathData(rapidPath: rapidPath, feeds: feedMap);
}

// Sample spacing in mm — coarser than G-code generation for rendering speed.
const _step = 0.5;

void _samplePath(
  String pathData,
  SvgAffine xform,
  Color color,
  void Function(List<Offset>, Color) addContour, {
  double offsetDeltaMm = 0.0,
}) {
  for (var pts in sampleContours(pathData,
      step: _step, minDistSq: 0.04, map: xform.apply)) {
    if (offsetDeltaMm != 0) {
      pts = PathOffset.offsetClosedContour(pts, offsetDeltaMm);
    }
    addContour(pts, color);
  }
}

void _sampleFill(
  String pathData,
  SvgAffine xform,
  LayerSettings settings,
  double inset,
  void Function(List<Offset>, Color) addContour,
) {
  final Path rawPath;
  try {
    rawPath = parseSvgPathData(pathData);
  } catch (_) {
    return;
  }
  final path = rawPath.transform(xform.toFloat64());
  final color = OperationType.fill.color;

  final lines = computeFillLines(
      path, settings.fillDirection, settings.linesPerMm, inset: inset);

  for (final line in lines) {
    addContour([line.$1, line.$2], color);
  }

  if (settings.fillOutline) {
    _samplePath(pathData, xform, color, addContour);
  }
}
