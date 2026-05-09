import 'dart:ui';
import 'package:xml/xml.dart';
import '../models/svg_document.dart';
import '../models/svg_node.dart';
import '../models/svg_node_type.dart';
import '../models/layer_settings.dart';

class SvgTreeParser {
  static const _skipTags = {
    'namedview', 'defs', 'metadata', 'title', 'desc',
    'style', 'script', 'symbol', 'clippath', 'filter',
  };

  static SvgDocument parse(String svgContent) {
    final XmlDocument xmlDoc;
    try {
      xmlDoc = XmlDocument.parse(svgContent);
    } catch (_) {
      return SvgDocument.empty();
    }

    final svgEl = xmlDoc.findElements('svg').firstOrNull;
    if (svgEl == null) return SvgDocument.empty();

    return SvgDocument(
      roots: _parseChildren(svgEl),
      viewBox: _viewBox(svgEl),
    );
  }

  static Rect _viewBox(XmlElement svg) {
    final vb = svg.getAttribute('viewBox');
    if (vb != null) {
      final p = vb.trim().split(RegExp(r'[\s,]+')).map((s) => double.tryParse(s) ?? 0).toList();
      if (p.length == 4) return Rect.fromLTWH(p[0], p[1], p[2], p[3]);
    }
    final w = double.tryParse(svg.getAttribute('width')?.replaceAll(RegExp(r'[a-zA-Z]'), '') ?? '') ?? 100;
    final h = double.tryParse(svg.getAttribute('height')?.replaceAll(RegExp(r'[a-zA-Z]'), '') ?? '') ?? 100;
    return Rect.fromLTWH(0, 0, w, h);
  }

  static List<SvgNode> _parseChildren(XmlElement parent) {
    final result = <SvgNode>[];
    int idx = 0;
    for (final child in parent.childElements) {
      final node = _parseEl(child, idx);
      if (node != null) {
        result.add(node);
        idx++;
      }
    }
    return result;
  }

  static SvgNode? _parseEl(XmlElement el, int idx) {
    final tag = el.localName.toLowerCase();
    if (_skipTags.contains(tag)) return null;

    final id = el.getAttribute('id') ?? '${tag}_$idx';
    final label = _inkAttr(el, 'label') ?? id;
    final transform = el.getAttribute('transform');

    if (tag == 'g') {
      final isLayer = _inkAttr(el, 'groupmode') == 'layer';
      return SvgNode(
        id: id,
        label: label,
        type: isLayer ? SvgNodeType.layer : SvgNodeType.group,
        children: _parseChildren(el),
        transform: transform,
        settings: LayerSettings(),
      );
    }

    final pathData = _toPath(el, tag);
    if (pathData == null || pathData.isEmpty) return null;

    return SvgNode(
      id: id,
      label: label,
      type: _type(tag),
      pathData: pathData,
      transform: transform,
      settings: LayerSettings(),
    );
  }

  static String? _inkAttr(XmlElement el, String localName) {
    for (final a in el.attributes) {
      if (a.localName == localName) return a.value;
    }
    return null;
  }

  static String? _toPath(XmlElement el, String tag) => switch (tag) {
        'path' => el.getAttribute('d'),
        'rect' => _rectPath(el),
        'ellipse' => _ellipsePath(_d(el, 'cx'), _d(el, 'cy'), _d(el, 'rx'), _d(el, 'ry')),
        'circle' => _ellipsePath(_d(el, 'cx'), _d(el, 'cy'), _d(el, 'r'), _d(el, 'r')),
        'line' => 'M ${_d(el, "x1")},${_d(el, "y1")} L ${_d(el, "x2")},${_d(el, "y2")}',
        'polyline' => _polyPath(el, close: false),
        'polygon' => _polyPath(el, close: true),
        _ => null,
      };

  static SvgNodeType _type(String tag) => switch (tag) {
        'path' => SvgNodeType.path,
        'rect' => SvgNodeType.rect,
        'ellipse' => SvgNodeType.ellipse,
        'circle' => SvgNodeType.circle,
        'line' => SvgNodeType.line,
        'polyline' => SvgNodeType.polyline,
        'polygon' => SvgNodeType.polygon,
        _ => SvgNodeType.unknown,
      };

  static String _rectPath(XmlElement el) {
    final x = _d(el, 'x'), y = _d(el, 'y'), w = _d(el, 'width'), h = _d(el, 'height');
    return 'M $x,$y L ${x + w},$y L ${x + w},${y + h} L $x,${y + h} Z';
  }

  static String _ellipsePath(double cx, double cy, double rx, double ry) =>
      'M ${cx + rx},$cy A $rx,$ry 0 1,0 ${cx - rx},$cy A $rx,$ry 0 1,0 ${cx + rx},$cy Z';

  static String? _polyPath(XmlElement el, {required bool close}) {
    final pts = el.getAttribute('points') ?? '';
    if (pts.isEmpty) return null;
    final coords = pts.trim().split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty).toList();
    if (coords.length < 4) return null;
    final sb = StringBuffer();
    for (int i = 0; i + 1 < coords.length; i += 2) {
      sb.write(i == 0 ? 'M ${coords[i]},${coords[i + 1]} ' : 'L ${coords[i]},${coords[i + 1]} ');
    }
    if (close) sb.write('Z');
    return sb.toString().trim();
  }

  static double _d(XmlElement el, String attr) =>
      double.tryParse(el.getAttribute(attr) ?? '0') ?? 0;
}
