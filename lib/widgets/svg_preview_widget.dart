import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';
import '../models/svg_document.dart';
import '../models/svg_node.dart';
import '../services/affine.dart';
import 'svg_document_painter.dart';

class SvgPreviewWidget extends StatefulWidget {
  final SvgDocument? document;
  final Offset? machinePos;
  final void Function(SvgNode?)? onCanvasSelect;
  /// SVG-space bounding rect to show as a dashed frame overlay.
  final Rect? frameBounds;

  const SvgPreviewWidget({
    super.key,
    this.document,
    this.machinePos,
    this.onCanvasSelect,
    this.frameBounds,
  });

  @override
  State<SvgPreviewWidget> createState() => _SvgPreviewWidgetState();
}

class _SvgPreviewWidgetState extends State<SvgPreviewWidget> {
  final _controller = TransformationController();
  Size _canvasSize = Size.zero;
  Offset? _cursorSvg;
  bool _showGrid = false;
  bool _showRulers = true;

  // Tap detection (Listener-based to avoid gesture arena conflicts)
  Offset? _pointerDown;
  bool _pointerMoved = false;

  static const _rulerW = 24.0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Coordinate math ──────────────────────────────────────────────

  /// Viewport pixel → SVG coordinate (accounts for IV transform + painter centering).
  Offset? _viewportToSvg(Offset vp) {
    final doc = widget.document;
    if (doc == null || _canvasSize == Size.zero) return null;
    final vb = doc.viewBox;
    try {
      final cp = MatrixUtils.transformPoint(
          Matrix4.inverted(_controller.value), vp);
      final s = math.min(_canvasSize.width / vb.width, _canvasSize.height / vb.height);
      final ox = (_canvasSize.width - vb.width * s) / 2 - vb.left * s;
      final oy = (_canvasSize.height - vb.height * s) / 2 - vb.top * s;
      return Offset((cp.dx - ox) / s, (cp.dy - oy) / s);
    } catch (_) {
      return null;
    }
  }

  // ── Zoom controls ────────────────────────────────────────────────

  void _zoom(double factor) {
    if (_canvasSize == Size.zero) return;
    final cx = _canvasSize.width / 2;
    final cy = _canvasSize.height / 2;
    final m = _controller.value;
    final s = m.storage[0];
    final newS = (s * factor).clamp(0.05, 100.0);
    final f = newS / s;
    final tx = m.storage[12], ty = m.storage[13];
    _controller.value = Matrix4.identity()
      ..setEntry(0, 0, newS)
      ..setEntry(1, 1, newS)
      ..setEntry(0, 3, cx * (1 - f) + tx * f)
      ..setEntry(1, 3, cy * (1 - f) + ty * f);
  }

  // ── Hit testing (click-to-select) ────────────────────────────────

  void _onTap(Offset viewportPos) {
    final doc = widget.document;
    if (doc == null) return;
    final svgPos = _viewportToSvg(viewportPos);
    if (svgPos == null) return;

    final ivScale = _controller.value.storage[0];
    final painterScale = _canvasSize == Size.zero
        ? 1.0
        : math.min(_canvasSize.width / doc.viewBox.width,
            _canvasSize.height / doc.viewBox.height);
    final threshold = 6.0 / (painterScale * ivScale);

    final hit = _hitNodes(doc.roots, svgPos, threshold, SvgAffine.identity);
    widget.onCanvasSelect?.call(hit); // null = clicked empty space
  }

  SvgNode? _hitNodes(
      List<SvgNode> nodes, Offset pt, double thr, SvgAffine pm) {
    for (final node in nodes.reversed) {
      if (!node.enabled) continue;
      final m = pm.multiply(SvgAffine.fromSvgString(node.transform));
      final child = _hitNodes(node.children, pt, thr, m);
      if (child != null) return child;
      if (node.pathData != null && _hitPath(node.pathData!, m, pt, thr)) {
        return node;
      }
    }
    return null;
  }

  bool _hitPath(
      String pathData, SvgAffine xform, Offset pt, double thr) {
    try {
      final path =
          parseSvgPathData(pathData).transform(xform.toFloat64());
      final thrSq = thr * thr;
      final sampleStep = math.max(thr * 2, 0.5);
      for (final metric in path.computeMetrics()) {
        for (var d = 0.0; d <= metric.length; d += sampleStep) {
          final t = metric.getTangentForOffset(d);
          if (t != null && (t.position - pt).distanceSquared <= thrSq) {
            return true;
          }
        }
      }
    } catch (_) {}
    return false;
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2C2C2C),
      child:
          widget.document == null ? _buildEmpty() : _buildCanvas(),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_outlined,
                size: 56, color: Colors.grey[600]),
            const SizedBox(height: 12),
            Text('Open an SVG file to get started',
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            const SizedBox(height: 4),
            Text('File → Open SVG file',
                style: TextStyle(color: Colors.grey[700], fontSize: 11)),
          ],
        ),
      );

  Widget _buildCanvas() {
    return Column(
      children: [
        if (_showRulers)
          SizedBox(
            height: _rulerW,
            child: Row(children: [
              const SizedBox(width: _rulerW), // corner
              Expanded(child: _buildRuler(Axis.horizontal)),
            ]),
          ),
        Expanded(
          child: Row(children: [
            if (_showRulers)
              SizedBox(width: _rulerW, child: _buildRuler(Axis.vertical)),
            Expanded(child: _buildInteractiveArea()),
          ]),
        ),
      ],
    );
  }

  Widget _buildRuler(Axis axis) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => CustomPaint(
        painter: _RulerPainter(
          axis: axis,
          viewBox: widget.document!.viewBox,
          canvasSize: _canvasSize,
          ivM: _controller.value,
        ),
      ),
    );
  }

  Widget _buildInteractiveArea() {
    return LayoutBuilder(builder: (_, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      if (_canvasSize != size) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _canvasSize != size) {
            setState(() => _canvasSize = size);
          }
        });
      }
      return Stack(children: [
        // IV canvas with pointer tracking
        Listener(
          onPointerDown: (e) {
            _pointerDown = e.localPosition;
            _pointerMoved = false;
          },
          onPointerMove: (e) {
            if (_pointerDown != null &&
                (e.localPosition - _pointerDown!).distance > 8) {
              _pointerMoved = true;
            }
          },
          onPointerUp: (e) {
            if (!_pointerMoved) _onTap(e.localPosition);
          },
          child: MouseRegion(
            onHover: (e) {
              final svg = _viewportToSvg(e.localPosition);
              if (svg != _cursorSvg) setState(() => _cursorSvg = svg);
            },
            onExit: (_) {
              if (_cursorSvg != null) setState(() => _cursorSvg = null);
            },
            child: InteractiveViewer(
              transformationController: _controller,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              minScale: 0.05,
              maxScale: 100,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: CustomPaint(
                  painter: SvgDocumentPainter(
                    document: widget.document!,
                    machinePos: widget.machinePos,
                    showGrid: _showGrid,
                    frameBounds: widget.frameBounds,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Cursor coordinates — bottom left (displayed in machine coords: origin at bottom-left)
        if (_cursorSvg != null)
          Positioned(
            bottom: 6,
            left: 6,
            child: _CursorCoords(
              svgPos: _cursorSvg!,
              viewBox: widget.document!.viewBox,
            ),
          ),

        // Controls — bottom right
        Positioned(
          bottom: 6,
          right: 6,
          child: _CanvasControls(
            showGrid: _showGrid,
            showRulers: _showRulers,
            onZoomIn: () => _zoom(1.25),
            onZoomOut: () => _zoom(0.8),
            onFit: () => _controller.value = Matrix4.identity(),
            onToggleGrid: () => setState(() => _showGrid = !_showGrid),
            onToggleRulers: () =>
                setState(() => _showRulers = !_showRulers),
          ),
        ),
      ]);
    });
  }
}

// ── Ruler painter ────────────────────────────────────────────────────────────

class _RulerPainter extends CustomPainter {
  final Axis axis;
  final Rect viewBox;
  final Size canvasSize;
  final Matrix4 ivM;

  const _RulerPainter({
    required this.axis,
    required this.viewBox,
    required this.canvasSize,
    required this.ivM,
  });

  // Convert SVG coordinate to ruler pixel.
  double _svgToRuler(double svg) {
    if (canvasSize == Size.zero) return 0;
    final vb = viewBox;
    final ps = math.min(
        canvasSize.width / vb.width, canvasSize.height / vb.height);
    if (axis == Axis.horizontal) {
      final off = (canvasSize.width - vb.width * ps) / 2 - vb.left * ps;
      final cx = svg * ps + off;
      return cx * ivM.storage[0] + ivM.storage[12];
    } else {
      final off = (canvasSize.height - vb.height * ps) / 2 - vb.top * ps;
      final cy = svg * ps + off;
      return cy * ivM.storage[5] + ivM.storage[13];
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(Offset.zero & size,
        Paint()..color = const Color(0xFF1C1C1C));

    if (canvasSize == Size.zero) return;

    final vb = viewBox;
    final ps = math.min(
        canvasSize.width / vb.width, canvasSize.height / vb.height);
    final ivScale =
        axis == Axis.horizontal ? ivM.storage[0] : ivM.storage[5];
    final effScale = ps * ivScale; // screen pixels per mm

    // Tick interval
    final double interval, majorEvery;
    if (effScale < 1.5) {
      interval = 100; majorEvery = 5;
    } else if (effScale < 4) {
      interval = 50; majorEvery = 2;
    } else if (effScale < 10) {
      interval = 10; majorEvery = 5;
    } else if (effScale < 30) {
      interval = 5; majorEvery = 2;
    } else if (effScale < 80) {
      interval = 1; majorEvery = 10;
    } else {
      interval = 0.5; majorEvery = 10;
    }

    final start = axis == Axis.horizontal ? vb.left : vb.top;
    final end = axis == Axis.horizontal ? vb.right : vb.bottom;

    final tickPaint = Paint()
      ..color = const Color(0xFF666666)
      ..strokeWidth = 0.5;
    final majorPaint = Paint()
      ..color = const Color(0xFF999999)
      ..strokeWidth = 0.5;

    var sv = (start / interval).floor() * interval;
    var idx = 0;
    while (sv <= end + interval) {
      final px = _svgToRuler(sv);
      final isMajor = (idx % majorEvery) == 0;
      final paint = isMajor ? majorPaint : tickPaint;

      if (axis == Axis.horizontal) {
        if (px >= 0 && px <= size.width) {
          final tickLen = isMajor ? 8.0 : 4.0;
          canvas.drawLine(Offset(px, size.height - tickLen),
              Offset(px, size.height), paint);
          if (isMajor) {
            // Horizontal ruler: machine X = svgX - vb.left
            final machineVal = sv - viewBox.left;
            _label(canvas, machineVal.round().toString(),
                Offset(px + 2, 1), false);
          }
        }
      } else {
        if (px >= 0 && px <= size.height) {
          final tickLen = isMajor ? 8.0 : 4.0;
          canvas.drawLine(Offset(size.width - tickLen, px),
              Offset(size.width, px), paint);
          if (isMajor) {
            // Vertical ruler: machine Y = vb.bottom - svgY (0 at bottom, increases upward)
            final machineVal = viewBox.bottom - sv;
            _label(canvas, machineVal.round().toString(),
                Offset(size.width / 2, px), true);
          }
        }
      }
      sv += interval;
      idx++;
    }

    // Border edge
    final border = Paint()
      ..color = const Color(0xFF444444)
      ..strokeWidth = 0.5;
    if (axis == Axis.horizontal) {
      canvas.drawLine(
          Offset(0, size.height), Offset(size.width, size.height), border);
    } else {
      canvas.drawLine(
          Offset(size.width, 0), Offset(size.width, size.height), border);
    }
  }

  void _label(Canvas canvas, String text, Offset pos, bool rotated) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
            color: Color(0xFF888888), fontSize: 8.5, height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    if (rotated) {
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(-math.pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height - 1));
      canvas.restore();
    } else {
      tp.paint(canvas, pos);
    }
  }

  @override
  bool shouldRepaint(_RulerPainter _) => true;
}

// ── Overlays ─────────────────────────────────────────────────────────────────

class _CursorCoords extends StatelessWidget {
  final Offset svgPos;
  final Rect viewBox;
  const _CursorCoords({required this.svgPos, required this.viewBox});

  @override
  Widget build(BuildContext context) {
    // Convert SVG coords to machine coords: origin at bottom-left of work area
    final mx = svgPos.dx - viewBox.left;
    final my = viewBox.bottom - svgPos.dy;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        'X ${mx.toStringAsFixed(2)}  Y ${my.toStringAsFixed(2)}',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

class _CanvasControls extends StatelessWidget {
  final bool showGrid, showRulers;
  final VoidCallback onZoomIn, onZoomOut, onFit;
  final VoidCallback onToggleGrid, onToggleRulers;

  const _CanvasControls({
    required this.showGrid,
    required this.showRulers,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
    required this.onToggleGrid,
    required this.onToggleRulers,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.straighten, onToggleRulers,
              showRulers ? 'Hide rulers' : 'Show rulers',
              active: showRulers),
          _btn(Icons.grid_4x4, onToggleGrid,
              showGrid ? 'Hide grid' : 'Show grid',
              active: showGrid),
          Container(width: 1, height: 16, color: Colors.white12),
          _btn(Icons.add, onZoomIn, 'Zoom in (+)'),
          _btn(Icons.remove, onZoomOut, 'Zoom out (-)'),
          _btn(Icons.fit_screen, onFit, 'Fit to view'),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap, String tooltip,
      {bool active = false}) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: Icon(
            icon,
            size: 15,
            color: active
                ? Colors.lightBlue.shade300
                : Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
