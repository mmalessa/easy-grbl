import 'dart:ui';
import 'svg_node.dart';

class SvgDocument {
  final List<SvgNode> roots;
  final Rect viewBox;

  /// How many physical millimetres one SVG coordinate unit represents.
  /// Defaults to 1.0 when the SVG has no physical size attributes.
  final double mmPerSvgUnit;

  const SvgDocument({
    required this.roots,
    required this.viewBox,
    this.mmPerSvgUnit = 1.0,
  });

  static SvgDocument empty() =>
      SvgDocument(roots: [], viewBox: Rect.fromLTWH(0, 0, 100, 100));
}
