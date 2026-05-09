import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';
import '../models/svg_document.dart';
import '../models/svg_node.dart';
import '../models/operation_type.dart';
import '../services/svg_transform.dart';

class SvgDocumentPainter extends CustomPainter {
  final SvgDocument document;
  final Offset? machinePos;
  final bool showGrid;
  /// SVG-space bounding rect of active paths; drawn as dashed overlay when set.
  final Rect? frameBounds;

  const SvgDocumentPainter({
    required this.document,
    this.machinePos,
    this.showGrid = false,
    this.frameBounds,
  });

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

    // Grid
    if (showGrid) _paintGrid(canvas, document.viewBox, scale);

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
      _paintNode(canvas, node, paint, true, null);
    }

    // Frame overlay (dashed bounding rect of active paths)
    if (frameBounds != null) {
      _paintFrameOverlay(canvas, frameBounds!, scale);
    }

    // Machine crosshair — convert machine coords (origin at bottom-left) to SVG coords
    if (machinePos != null) {
      final svgPos = Offset(vb.left + machinePos!.dx, vb.bottom - machinePos!.dy);
      _paintCrosshair(canvas, svgPos, scale);
    }

    canvas.restore();
  }

  void _paintGrid(Canvas canvas, Rect vb, double scale) {
    final minorPaint = Paint()
      ..color = const Color(0xFF888888).withValues(alpha: 0.18)
      ..strokeWidth = 0.4 / scale;
    final majorPaint = Paint()
      ..color = const Color(0xFF888888).withValues(alpha: 0.35)
      ..strokeWidth = 0.4 / scale;

    void drawLines(double interval, Paint p) {
      var x = (vb.left / interval).ceil() * interval;
      while (x <= vb.right) {
        canvas.drawLine(Offset(x, vb.top), Offset(x, vb.bottom), p);
        x += interval;
      }
      var y = (vb.top / interval).ceil() * interval;
      while (y <= vb.bottom) {
        canvas.drawLine(Offset(vb.left, y), Offset(vb.right, y), p);
        y += interval;
      }
    }

    drawLines(10, majorPaint);
    if (scale >= 2.5) drawLines(1, minorPaint); // minor grid only when zoomed in
  }

  void _paintFrameOverlay(Canvas canvas, Rect bounds, double scale) {
    // Semi-transparent fill
    canvas.drawRect(
      bounds,
      Paint()..color = const Color(0xFF1565C0).withValues(alpha: 0.06),
    );

    // Dashed stroke
    final sw = 1.5 / scale;
    final dash = 5.0 / scale;
    final gap = 3.0 / scale;
    final framePaint = Paint()
      ..color = const Color(0xFF1E88E5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw;

    final path = Path()..addRect(bounds);
    final dashed = dashPath(
        path, dashArray: CircularIntervalList<double>([dash, gap]));
    canvas.drawPath(dashed, framePaint);

    // Corner L-markers
    final ml = 6.0 / scale;
    final markerPaint = Paint()
      ..color = const Color(0xFF1E88E5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw * 1.8
      ..strokeCap = StrokeCap.square;

    for (final c in [
      (x: bounds.left, y: bounds.top, sx: 1.0, sy: 1.0),
      (x: bounds.right, y: bounds.top, sx: -1.0, sy: 1.0),
      (x: bounds.right, y: bounds.bottom, sx: -1.0, sy: -1.0),
      (x: bounds.left, y: bounds.bottom, sx: 1.0, sy: -1.0),
    ]) {
      final p = Path()
        ..moveTo(c.x + c.sx * ml, c.y)
        ..lineTo(c.x, c.y)
        ..lineTo(c.x, c.y + c.sy * ml);
      canvas.drawPath(p, markerPaint);
    }
  }

  void _paintCrosshair(Canvas canvas, Offset pos, double scale) {
    final vb = document.viewBox;
    final linePaint = Paint()
      ..color = const Color(0xBBFF3333)
      ..strokeWidth = 0.4 / scale
      ..style = PaintingStyle.stroke;

    // Horizontal + vertical hair lines
    canvas.drawLine(Offset(vb.left, pos.dy), Offset(vb.right, pos.dy), linePaint);
    canvas.drawLine(Offset(pos.dx, vb.top), Offset(pos.dx, vb.bottom), linePaint);

    // Small circle at position
    canvas.drawCircle(
      pos,
      1.8 / scale,
      Paint()
        ..color = const Color(0xFFFF3333)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5 / scale,
    );
  }

  void _paintNode(
    Canvas canvas,
    SvgNode node,
    Paint paint,
    bool parentEnabled,
    OperationType? inheritedOp,
  ) {
    final visible = parentEnabled && node.enabled;

    // Resolve effective operation type (own overrides inherited)
    final ownOp = node.settings.operationType;
    final effectiveOp = ownOp != OperationType.skip ? ownOp : inheritedOp;

    final hasTransform = node.transform != null && node.transform!.isNotEmpty;
    if (hasTransform) canvas.save();
    applySvgTransform(canvas, node.transform);

    if (node.pathData != null) {
      try {
        final path = parseSvgPathData(node.pathData!);
        paint.color = _pathColor(node, visible, effectiveOp);
        canvas.drawPath(path, paint);
      } catch (_) {}
    }

    for (final child in node.children) {
      _paintNode(canvas, child, paint, visible, effectiveOp);
    }

    if (hasTransform) canvas.restore();
  }

  Color _pathColor(SvgNode node, bool visible, OperationType? effectiveOp) {
    if (!visible) return Colors.black.withValues(alpha: 0.12);
    if (node.selected) return Colors.blue.shade400;
    if (effectiveOp != null && effectiveOp != OperationType.skip) {
      return effectiveOp.color.withValues(alpha: 0.85);
    }
    return Colors.black87;
  }

  @override
  bool shouldRepaint(covariant SvgDocumentPainter old) => true;
}
