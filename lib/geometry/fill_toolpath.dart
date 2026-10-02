import 'dart:ui';
import '../models/layer_settings.dart';
import 'contour_sampler.dart';
import 'fill_lines.dart';
import 'path_offset.dart';

const double _sampleStep = 0.1; // mm per sample along the shape's edges

/// What a Fill layer burns for one shape: scanline hatch plus the optional
/// outline contours, all in the same space as the input path.
class FillToolpath {
  final List<(Offset, Offset)> lines;
  final List<List<Offset>> outline;

  const FillToolpath({required this.lines, required this.outline});
}

/// Fill toolpath for [path] (already transformed, units of mm) burned with a
/// spot/tool of [spotDiameter]. Both the hatch and the outline run on the
/// shape shrunk by half the spot (holes grow by the same amount), so the
/// burned area matches the filled shape exactly instead of spilling half a
/// spot past its edge.
///
/// A shape narrower than the spot everywhere can't hold it; it falls back to
/// running on the original edge, with the hatch inset by half a spot when an
/// outline is burned.
FillToolpath computeFillToolpath(
  Path path, {
  required FillDirection direction,
  required double linesPerMm,
  required double spotDiameter,
  required bool outline,
}) {
  final edge = samplePathContours(path, step: _sampleStep, minDistSq: 1e-6);
  final inner = PathOffset.insetFilledRegion(edge, spotDiameter / 2);

  if (inner.isEmpty) {
    return FillToolpath(
      lines: computeFillLines(path, direction, linesPerMm,
          inset: outline ? spotDiameter / 2 : 0.0),
      outline: outline ? edge : const [],
    );
  }

  final innerPath = Path()..fillType = PathFillType.evenOdd;
  for (final c in inner) {
    innerPath.addPolygon(c, true);
  }
  return FillToolpath(
    lines: computeFillLines(innerPath, direction, linesPerMm),
    outline: outline ? inner : const [],
  );
}
