import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';
import '../models/svg_document.dart';
import '../models/svg_node.dart';
import '../services/svg_transform.dart';

class SvgDocumentPainter extends CustomPainter {
  final SvgDocument document;

  const SvgDocumentPainter({required this.document});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || document.roots.isEmpty) return;

    final vb = document.viewBox;
    final scale = math.min(size.width / vb.width, size.height / vb.height);
    final offsetX = (size.width - vb.width * scale) / 2;
    final offsetY = (size.height - vb.height * scale) / 2;

    // Shadow behind work area (screen coords, before transform)
    canvas.drawRect(
      Rect.fromLTWH(offsetX + 4, offsetY + 4, vb.width * scale, vb.height * scale),
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );

    canvas.save();
    canvas.translate(offsetX - vb.left * scale, offsetY - vb.top * scale);
    canvas.scale(scale);

    // White work area
    canvas.drawRect(document.viewBox, Paint()..color = Colors.white);
    canvas.drawRect(
      document.viewBox,
      Paint()
        ..color = Colors.grey.shade400
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5 / scale,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5 / scale;

    for (final node in document.roots) {
      _paintNode(canvas, node, paint, true);
    }

    canvas.restore();
  }

  void _paintNode(Canvas canvas, SvgNode node, Paint paint, bool parentEnabled) {
    final visible = parentEnabled && node.enabled;
    final hasTransform = node.transform != null && node.transform!.isNotEmpty;

    if (hasTransform) canvas.save();
    applySvgTransform(canvas, node.transform);

    if (node.pathData != null) {
      try {
        final path = parseSvgPathData(node.pathData!);
        paint.color = _pathColor(node, visible);
        canvas.drawPath(path, paint);
      } catch (_) {}
    }

    for (final child in node.children) {
      _paintNode(canvas, child, paint, visible);
    }

    if (hasTransform) canvas.restore();
  }

  Color _pathColor(SvgNode node, bool visible) {
    if (!visible) return Colors.black.withValues(alpha: 0.15);
    if (node.selected) return Colors.blue;
    return Colors.black87;
  }

  @override
  bool shouldRepaint(covariant SvgDocumentPainter old) => true;
}
