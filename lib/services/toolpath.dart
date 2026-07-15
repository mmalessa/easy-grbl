import 'dart:ui';
import 'package:path_drawing/path_drawing.dart';
import '../models/svg_document.dart';
import '../models/svg_node.dart';
import '../models/operation_type.dart';
import '../models/layer_settings.dart';
import '../models/machine_settings.dart';
import 'affine.dart';
import 'gcode_generator.dart';
import 'path_offset.dart';

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

  _walkNodes(doc.roots, SvgAffine.identity, true, null, null, machineSettings,
      addContour);

  if (!hasAny) return null;

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
  LayerSettings? inheritedSettings,
  MachineSettings machineSettings,
  void Function(List<Offset>, Color) addContour,
) {
  for (final node in nodes) {
    if (!node.enabled || !parentEnabled) continue;
    final m = parentM.multiply(SvgAffine.fromSvgString(node.transform));
    final ownOp = node.settings.operationType;
    final eff = ownOp != OperationType.skip ? ownOp : inheritedOp;
    final effSettings =
        ownOp != OperationType.skip ? node.settings : (inheritedSettings ?? node.settings);
    if (node.pathData != null && eff != null && eff != OperationType.skip) {
      if (eff == OperationType.fill) {
        _sampleFill(node.pathData!, m, effSettings, machineSettings.laserSpotSize, addContour);
      } else {
        final offsetDelta = eff == OperationType.cut
            ? _cutOffsetDelta(machineSettings, effSettings)
            : 0.0;
        for (var pass = 0; pass < effSettings.passes; pass++) {
          _samplePath(node.pathData!, m, eff.color, addContour,
              offsetDeltaMm: offsetDelta);
        }
      }
    }
    _walkNodes(node.children, m, node.enabled, eff,
        ownOp != OperationType.skip ? node.settings : inheritedSettings,
        machineSettings, addContour);
  }
}

/// Signed XY offset (mm) for a Cut layer's toolpath: outer grows, inner
/// shrinks, by the tool/spot's effective diameter at the layer's cut depth.
double _cutOffsetDelta(MachineSettings machineSettings, LayerSettings s) {
  final effDiam = machineSettings.effectiveDiameterAt(s.cutDepthMm);
  return switch (s.cutSide) {
    CutSide.line => 0.0,
    CutSide.outer => effDiam / 2,
    CutSide.inner => -effDiam / 2,
  };
}

void _samplePath(
  String pathData,
  SvgAffine xform,
  Color color,
  void Function(List<Offset>, Color) addContour, {
  double offsetDeltaMm = 0.0,
}) {
  final Path path;
  try {
    path = parseSvgPathData(pathData);
  } catch (_) {
    return;
  }
  for (final metric in path.computeMetrics()) {
    if (metric.length < 0.001) continue;
    var pts = <Offset>[];
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
    if (pts.length < 2) continue;
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
  double spotSize,
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
  final inset = settings.fillOutline ? spotSize / 2 : 0.0;

  final lines = GcodeGenerator.computeFillLines(
      path, settings.fillDirection, settings.linesPerMm, inset: inset);

  for (final line in lines) {
    addContour([line.$1, line.$2], color);
  }

  if (settings.fillOutline) {
    _samplePath(pathData, xform, color, addContour);
  }
}
