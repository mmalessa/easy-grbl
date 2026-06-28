import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';
import '../models/svg_document.dart';
import '../models/svg_node.dart';
import '../models/operation_type.dart';
import '../services/svg_transform.dart';
import '../services/toolpath.dart';

class SvgDocumentPainter extends CustomPainter {
  final SvgDocument document;
  final Offset? machinePos;
  final bool showGrid;
  final bool showAxes;
  final ToolpathData? toolpath;
  final double marginPx;

  const SvgDocumentPainter({
    required this.document,
    this.machinePos,
    this.showGrid = false,
    this.showAxes = true,
    this.toolpath,
    this.marginPx = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || document.roots.isEmpty) return;

    final vb = document.viewBox;
    final dw = (size.width - 2 * marginPx).clamp(1, double.infinity);
    final dh = (size.height - 2 * marginPx).clamp(1, double.infinity);
    final scale = math.min(dw / vb.width, dh / vb.height);
    final offsetX = marginPx + (dw - vb.width * scale) / 2;
    final offsetY = marginPx + (dh - vb.height * scale) / 2;

    // Shadow behind work area (screen coords, before transform)
    canvas.drawRect(
      Rect.fromLTWH(offsetX + 4, offsetY + 4, vb.width * scale, vb.height * scale),
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );

    canvas.save();
    canvas.translate(offsetX - vb.left * scale, offsetY - vb.top * scale);
    canvas.scale(scale);

    // Light grey work area
    canvas.drawRect(document.viewBox, Paint()..color = Colors.grey[100]!);

    // Grid
    if (showGrid) _paintGrid(canvas, document.viewBox, scale);

    canvas.drawRect(
      document.viewBox,
      Paint()
        ..color = Colors.grey.shade400
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5 / scale,
    );

    // X / Y axes on the work area edges
    if (showAxes) _paintAxes(canvas, document.viewBox, scale);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5 / scale;

    for (final node in document.roots) {
      _paintNode(canvas, node, paint, true, null, false);
    }

    // Toolpath overlay (actual tool movement preview)
    if (toolpath != null) _paintToolpath(canvas, toolpath!, scale);

    // Machine crosshair — convert machine coords (origin at bottom-left) to SVG coords
    if (machinePos != null) {
      final svgPos = Offset(vb.left + machinePos!.dx, vb.bottom - machinePos!.dy);
      _paintCrosshair(canvas, svgPos, scale);
    }

    canvas.restore();
  }

  void _paintAxes(Canvas canvas, Rect vb, double scale) {
    const tickL = 0.5; // mm
    final off = 20 / scale;
    final gap = 3 / scale;
    final axisPaint = Paint()
      ..color = Colors.grey[700]!
      ..strokeWidth = 0.5 / scale
      ..style = PaintingStyle.stroke;
    final tickPaint = Paint()
      ..color = Colors.grey[600]!
      ..strokeWidth = 0.4 / scale;
    final labelStyle = TextStyle(
      color: Colors.grey[800]!,
      fontSize: 9 / scale,
      height: 1,
    );

    // ── X axis (below work area) ──
    final xY = vb.bottom + off;
    canvas.drawLine(Offset(vb.left, xY), Offset(vb.right, xY), axisPaint);
    _label(canvas, '0', Offset(vb.left, xY + tickL + gap), labelStyle);

    // ── Y axis (left of work area) ──
    final yX = vb.left - off;
    canvas.drawLine(Offset(yX, vb.bottom), Offset(yX, vb.top), axisPaint);
    _label(canvas, '0', Offset(yX - tickL - gap, vb.bottom), labelStyle);

    // ── Ticks ──
    final extent = math.max(vb.width, vb.height);
    final step = extent > 50 ? 10.0 : extent > 20 ? 5.0 : extent > 5 ? 1.0 : 0.5;
    final majorEvery = 5;

    var sv = (vb.left / step).ceil() * step;
    var idx = 0;
    while (sv <= vb.right) {
      final isMajor = (idx % majorEvery) == 0;
      canvas.drawLine(
        Offset(sv, xY),
        Offset(sv, xY + tickL),
        isMajor ? tickPaint : axisPaint,
      );
      if (isMajor && sv > vb.left) {
        _label(canvas, (sv - vb.left).round().toString(),
            Offset(sv, xY + tickL + gap), labelStyle);
      }
      sv += step;
      idx++;
    }

    sv = (vb.bottom / step).floor() * step;
    idx = 0;
    while (sv >= vb.top) {
      final isMajor = (idx % majorEvery) == 0;
      canvas.drawLine(
        Offset(yX - tickL, sv),
        Offset(yX, sv),
        isMajor ? tickPaint : axisPaint,
      );
      if (isMajor && sv < vb.bottom) {
        _label(canvas, (vb.bottom - sv).round().toString(),
            Offset(yX - tickL - gap, sv), labelStyle);
      }
      sv -= step;
      idx++;
    }
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

  void _paintToolpath(Canvas canvas, ToolpathData tp, double scale) {
    // Feed paths (laser on) — solid, coloured by operation type
    for (final entry in tp.feeds.entries) {
      canvas.drawPath(
        entry.value,
        Paint()
          ..color = entry.key.withValues(alpha: 0.80)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.55 / scale
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    // Rapid moves (laser off) — dashed grey
    final dashed = dashPath(
      tp.rapidPath,
      dashArray: CircularIntervalList<double>([3.0 / scale, 2.0 / scale]),
    );
    canvas.drawPath(
      dashed,
      Paint()
        ..color = const Color(0xFF999999).withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.3 / scale,
    );
  }

  void _paintCrosshair(Canvas canvas, Offset pos, double scale) {
    final vb = document.viewBox;
    final linePaint = Paint()
      ..color = const Color(0xCCFF3333)
      ..strokeWidth = 1.0 / scale
      ..style = PaintingStyle.stroke;

    // Horizontal + vertical hair lines (extend 8mm beyond work area so they're
    // visible even when the tool is at the border)
    const ext = 8.0;
    canvas.drawLine(
        Offset(vb.left - ext, pos.dy), Offset(vb.right + ext, pos.dy), linePaint);
    canvas.drawLine(
        Offset(pos.dx, vb.top - ext), Offset(pos.dx, vb.bottom + ext), linePaint);

    // Circle at position
    canvas.drawCircle(
      pos,
      4.0 / scale,
      Paint()
        ..color = const Color(0xFFFF3333)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 / scale,
    );
  }

  void _paintNode(
    Canvas canvas,
    SvgNode node,
    Paint paint,
    bool parentEnabled,
    OperationType? inheritedOp,
    bool inSelectedScope,
  ) {
    final visible = parentEnabled && node.enabled;
    final selected = inSelectedScope || node.selected;

    // Resolve effective operation type (own overrides inherited)
    final ownOp = node.settings.operationType;
    final effectiveOp = ownOp != OperationType.skip ? ownOp : inheritedOp;

    if (node.transform != null && node.transform!.isNotEmpty) {
      canvas.save();
      applySvgTransform(canvas, node.transform);
    }

    if (node.pathData != null) {
      try {
        final path = parseSvgPathData(node.pathData!);
        final sw = paint.strokeWidth;
        final isFillOp = visible && effectiveOp == OperationType.fill;
        if (isFillOp) {
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.fill
              ..color = OperationType.fill.color.withValues(alpha: 0.18),
          );
          paint.color = OperationType.fill.color.withValues(alpha: 0.55);
        } else {
          paint.color = _pathColor(node, visible, effectiveOp);
        }
        canvas.drawPath(path, paint);

        if (selected && visible) {
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..color = Colors.blue.shade400
              ..strokeWidth = sw * 3,
          );
        }
      } catch (_) {}
    }

    for (final child in node.children) {
      _paintNode(canvas, child, paint, visible, effectiveOp, selected);
    }

    if (node.transform != null && node.transform!.isNotEmpty) canvas.restore();
  }

  Color _pathColor(SvgNode node, bool visible, OperationType? effectiveOp) {
    if (!visible) return Colors.black.withValues(alpha: 0.12);
    if (effectiveOp != null && effectiveOp != OperationType.skip) {
      return effectiveOp.color.withValues(alpha: 0.85);
    }
    if (node.selected) return Colors.blue.shade400;
    return Colors.black87;
  }

  void _label(Canvas canvas, String text, Offset pos, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height));
  }

  @override
  bool shouldRepaint(covariant SvgDocumentPainter old) => true;
}
