import 'dart:ui';
import 'svg_node.dart';

class SvgDocument {
  final List<SvgNode> roots;
  final Rect viewBox;

  const SvgDocument({required this.roots, required this.viewBox});

  static SvgDocument empty() =>
      SvgDocument(roots: [], viewBox: Rect.fromLTWH(0, 0, 100, 100));
}
