import 'dart:ui';
import 'svg_path_model.dart';

class SvgPathParser {
  /// Extracts all paths from SVG and converts various elements to paths
  static List<SvgPathModel> extractPaths(String svgContent) {
    final List<SvgPathModel> result = [];

    result.addAll(_extractPathElements(svgContent));
    result.addAll(_extractRectElements(svgContent));
    result.addAll(_extractEllipseElements(svgContent));
    result.addAll(_extractCircleElements(svgContent));
    result.addAll(_extractLineElements(svgContent));
    result.addAll(_extractPolylineElements(svgContent));
    result.addAll(_extractPolygonElements(svgContent));

    return result;
  }

  static Rect extractViewBox(String svgContent) {
    final viewBoxRegExp = RegExp(r'viewBox="([^"]+)"');
    final match = viewBoxRegExp.firstMatch(svgContent);
    if (match != null) {
      final parts = match.group(1)!.split(RegExp(r'\s+')).map((e) => double.tryParse(e) ?? 0).toList();
      if (parts.length == 4) {
        return Rect.fromLTWH(parts[0], parts[1], parts[2], parts[3]);
      }
    }
    return Rect.fromLTWH(0, 0, 100, 100);
  }

  /// ---------------------- PATH
  static List<SvgPathModel> _extractPathElements(String svgContent) {
    final List<SvgPathModel> result = [];
    final pathTagRegExp = RegExp(r'<path\s+([^>]+?)/?>', multiLine: true);
    final pathTags = pathTagRegExp.allMatches(svgContent);

    for (final tag in pathTags) {
      final attrString = tag.group(1)!;
      final idMatch = RegExp(r'id="([^"]+)"').firstMatch(attrString);
      final id = idMatch != null ? idMatch.group(1)! : 'path_${result.length}';
      final dMatch = RegExp(r'd="([^"]+)"').firstMatch(attrString);
      if (dMatch != null) {
        final d = _fixPath(dMatch.group(1)!);
        result.add(SvgPathModel(id: id, d: d));
      }
    }

    return result;
  }

  /// ---------------------- RECT
  static List<SvgPathModel> _extractRectElements(String svgContent) {
    final List<SvgPathModel> result = [];
    final rectTagRegExp = RegExp(r'<rect\s+([^>]+?)/?>', multiLine: true);
    final rectTags = rectTagRegExp.allMatches(svgContent);

    for (final tag in rectTags) {
      final attrString = tag.group(1)!;
      final id = RegExp(r'id="([^"]+)"').firstMatch(attrString)?.group(1) ?? 'rect_${result.length}';
      final x = double.tryParse(RegExp(r'x="([^"]+)"').firstMatch(attrString)?.group(1) ?? '0') ?? 0;
      final y = double.tryParse(RegExp(r'y="([^"]+)"').firstMatch(attrString)?.group(1) ?? '0') ?? 0;
      final width = double.tryParse(RegExp(r'width="([^"]+)"').firstMatch(attrString)?.group(1) ?? '0') ?? 0;
      final height = double.tryParse(RegExp(r'height="([^"]+)"').firstMatch(attrString)?.group(1) ?? '0') ?? 0;
      final d = 'M $x,$y L ${x + width},$y L ${x + width},${y + height} L $x,${y + height} Z';
      result.add(SvgPathModel(id: id, d: d));
    }

    return result;
  }

  /// ---------------------- ELLIPSE
  static List<SvgPathModel> _extractEllipseElements(String svgContent) {
    final List<SvgPathModel> result = [];
    final ellipseTagRegExp = RegExp(r'<ellipse\s+([^>]+?)/?>', multiLine: true);
    final ellipseTags = ellipseTagRegExp.allMatches(svgContent);

    for (final tag in ellipseTags) {
      final attrString = tag.group(1)!;
      final id = RegExp(r'id="([^"]+)"').firstMatch(attrString)?.group(1) ?? 'ellipse_${result.length}';
      final cx = double.tryParse(RegExp(r'cx="([^"]+)"').firstMatch(attrString)?.group(1) ?? '0') ?? 0;
      final cy = double.tryParse(RegExp(r'cy="([^"]+)"').firstMatch(attrString)?.group(1) ?? '0') ?? 0;
      final rx = double.tryParse(RegExp(r'rx="([^"]+)"').firstMatch(attrString)?.group(1) ?? '0') ?? 0;
      final ry = double.tryParse(RegExp(r'ry="([^"]+)"').firstMatch(attrString)?.group(1) ?? '0') ?? 0;
      result.add(SvgPathModel(id: id, d: _ellipseToPath(cx, cy, rx, ry)));
    }

    return result;
  }

  /// ---------------------- CIRCLE
  static List<SvgPathModel> _extractCircleElements(String svgContent) {
    final List<SvgPathModel> result = [];
    final circleTagRegExp = RegExp(r'<circle\s+([^>]+?)/?>', multiLine: true);
    final circleTags = circleTagRegExp.allMatches(svgContent);

    for (final tag in circleTags) {
      final attrString = tag.group(1)!;
      final id = RegExp(r'id="([^"]+)"').firstMatch(attrString)?.group(1) ?? 'circle_${result.length}';
      final cx = double.tryParse(RegExp(r'cx="([^"]+)"').firstMatch(attrString)?.group(1) ?? '0') ?? 0;
      final cy = double.tryParse(RegExp(r'cy="([^"]+)"').firstMatch(attrString)?.group(1) ?? '0') ?? 0;
      final r = double.tryParse(RegExp(r'r="([^"]+)"').firstMatch(attrString)?.group(1) ?? '0') ?? 0;
      result.add(SvgPathModel(id: id, d: _ellipseToPath(cx, cy, r, r)));
    }

    return result;
  }

  /// ---------------------- LINE
  static List<SvgPathModel> _extractLineElements(String svgContent) {
    final List<SvgPathModel> result = [];
    final lineTagRegExp = RegExp(r'<line\s+([^>]+?)/?>', multiLine: true);
    final lineTags = lineTagRegExp.allMatches(svgContent);

    for (final tag in lineTags) {
      final attrString = tag.group(1)!;
      final id = RegExp(r'id="([^"]+)"').firstMatch(attrString)?.group(1) ?? 'line_${result.length}';
      final x1 = double.tryParse(RegExp(r'x1="([^"]+)"').firstMatch(attrString)?.group(1) ?? '0') ?? 0;
      final y1 = double.tryParse(RegExp(r'y1="([^"]+)"').firstMatch(attrString)?.group(1) ?? '0') ?? 0;
      final x2 = double.tryParse(RegExp(r'x2="([^"]+)"').firstMatch(attrString)?.group(1) ?? '0') ?? 0;
      final y2 = double.tryParse(RegExp(r'y2="([^"]+)"').firstMatch(attrString)?.group(1) ?? '0') ?? 0;
      result.add(SvgPathModel(id: id, d: 'M $x1,$y1 L $x2,$y2'));
    }

    return result;
  }

  /// ---------------------- POLYLINE
  static List<SvgPathModel> _extractPolylineElements(String svgContent) {
    final List<SvgPathModel> result = [];
    final polylineTagRegExp = RegExp(r'<polyline\s+([^>]+?)/?>', multiLine: true);
    final polylineTags = polylineTagRegExp.allMatches(svgContent);

    for (final tag in polylineTags) {
      final attrString = tag.group(1)!;
      final id = RegExp(r'id="([^"]+)"').firstMatch(attrString)?.group(1) ?? 'polyline_${result.length}';
      final pointsAttr = RegExp(r'points="([^"]+)"').firstMatch(attrString)?.group(1) ?? '';
      if (pointsAttr.isNotEmpty) {
        final points = pointsAttr.trim().split(RegExp(r'[\s,]+'));
        if (points.length >= 2) {
          final sb = StringBuffer();
          for (int i = 0; i < points.length; i += 2) {
            final x = points[i];
            final y = points[i + 1];
            sb.write(i == 0 ? 'M $x,$y ' : 'L $x,$y ');
          }
          result.add(SvgPathModel(id: id, d: sb.toString().trim()));
        }
      }
    }

    return result;
  }

  /// ---------------------- POLYGON
  static List<SvgPathModel> _extractPolygonElements(String svgContent) {
    final List<SvgPathModel> result = [];
    final polygonTagRegExp = RegExp(r'<polygon\s+([^>]+?)/?>', multiLine: true);
    final polygonTags = polygonTagRegExp.allMatches(svgContent);

    for (final tag in polygonTags) {
      final attrString = tag.group(1)!;
      final id = RegExp(r'id="([^"]+)"').firstMatch(attrString)?.group(1) ?? 'polygon_${result.length}';
      final pointsAttr = RegExp(r'points="([^"]+)"').firstMatch(attrString)?.group(1) ?? '';
      if (pointsAttr.isNotEmpty) {
        final points = pointsAttr.trim().split(RegExp(r'[\s,]+'));
        if (points.length >= 2) {
          final sb = StringBuffer();
          for (int i = 0; i < points.length; i += 2) {
            final x = points[i];
            final y = points[i + 1];
            sb.write(i == 0 ? 'M $x,$y ' : 'L $x,$y ');
          }
          sb.write('Z'); // close path
          result.add(SvgPathModel(id: id, d: sb.toString().trim()));
        }
      }
    }

    return result;
  }

  /// ----------------------
  static String _ellipseToPath(double cx, double cy, double rx, double ry) {
    return 'M ${cx + rx},$cy '
        'A $rx,$ry 0 1,0 ${cx - rx},$cy '
        'A $rx,$ry 0 1,0 ${cx + rx},$cy Z';
  }

  static String _fixPath(String d) {
    final trimmed = d.trim();
    if (trimmed.isEmpty) return trimmed;
    if (!trimmed.startsWith(RegExp(r'[Mm]'))) {
      return 'M0,0 $trimmed';
    }
    return trimmed;
  }
}
