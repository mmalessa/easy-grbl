import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/svg_document.dart';
import '../services/toolpath.dart';
import 'svg_document_painter.dart';

/// Visual margin (in pixels) around the SVG work area so ruler labels
/// at the viewBox edges have room to be displayed without clipping.
const _marginPx = 14.0;

class SvgPreviewWidget extends StatefulWidget {
  final SvgDocument? document;
  final Offset? machinePos;
  /// Pre-computed toolpath to optionally overlay on the canvas.
  final ToolpathData? toolpath;
  /// Double-click callback — receives machine coordinates (X right, Y up).
  final void Function(double x, double y)? onJogTo;

  const SvgPreviewWidget({
    super.key,
    this.document,
    this.machinePos,
    this.toolpath,
    this.onJogTo,
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
  bool _showToolpath = false;

  // Click / double-click detection (Listener-based to avoid gesture arena conflicts)
  Offset? _pointerDown;
  bool _pointerMoved = false;
  DateTime? _lastTapTime;
  Offset? _lastTapPos;

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
      final dw = (_canvasSize.width - 2 * _marginPx).clamp(1, double.infinity);
      final dh = (_canvasSize.height - 2 * _marginPx).clamp(1, double.infinity);
      final s = math.min(dw / vb.width, dh / vb.height);
      final ox = _marginPx + (dw - vb.width * s) / 2 - vb.left * s;
      final oy = _marginPx + (dh - vb.height * s) / 2 - vb.top * s;
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

  // ── Double-click → jog to position ──────────────────────────────

  void _onDoubleClick(Offset viewportPos) {
    final doc = widget.document;
    if (doc == null) return;
    final svgPos = _viewportToSvg(viewportPos);
    if (svgPos == null) return;
    final vb = doc.viewBox;
    widget.onJogTo?.call(svgPos.dx - vb.left, vb.bottom - svgPos.dy);
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE0E0E0),
      child:
          widget.document == null ? _buildEmpty() : _buildCanvas(),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_outlined,
                size: 56, color: Colors.grey[500]),
            const SizedBox(height: 12),
            Text('Open an SVG file to get started',
                style: TextStyle(color: Colors.grey[700], fontSize: 13)),
            const SizedBox(height: 4),
            Text('File → Open SVG file',
                style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          ],
        ),
      );

  Widget _buildCanvas() {
    return SizedBox.expand(child: _buildInteractiveArea());
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
            if (_pointerMoved) return;
            final pos = e.localPosition;
            final now = DateTime.now();
            if (_lastTapTime != null &&
                now.difference(_lastTapTime!) <=
                    const Duration(milliseconds: 300) &&
                _lastTapPos != null &&
                (pos - _lastTapPos!).distance <= 20) {
              _lastTapTime = null;
              _lastTapPos = null;
              _onDoubleClick(pos);
            } else {
              _lastTapTime = now;
              _lastTapPos = pos;
            }
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
                    showAxes: _showRulers,
                    toolpath: _showToolpath ? widget.toolpath : null,
                    marginPx: _marginPx,
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
            showToolpath: _showToolpath,
            hasToolpath: widget.toolpath != null,
            onToggleToolpath: () =>
                setState(() => _showToolpath = !_showToolpath),
          ),
        ),
      ]);
    });
  }
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
  final bool showGrid, showRulers, showToolpath, hasToolpath;
  final VoidCallback onZoomIn, onZoomOut, onFit;
  final VoidCallback onToggleGrid, onToggleRulers, onToggleToolpath;

  const _CanvasControls({
    required this.showGrid,
    required this.showRulers,
    required this.showToolpath,
    required this.hasToolpath,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
    required this.onToggleGrid,
    required this.onToggleRulers,
    required this.onToggleToolpath,
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
          _btn(Icons.route, onToggleToolpath,
              showToolpath ? 'Hide toolpath' : 'Show toolpath',
              active: showToolpath,
              disabled: !hasToolpath),
          Container(width: 1, height: 16, color: Colors.white12),
          _btn(Icons.add, onZoomIn, 'Zoom in (+)'),
          _btn(Icons.remove, onZoomOut, 'Zoom out (-)'),
          _btn(Icons.fit_screen, onFit, 'Fit to view'),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap, String tooltip,
      {bool active = false, bool disabled = false}) {
    final color = disabled
        ? Colors.white.withValues(alpha: 0.2)
        : active
            ? Colors.lightBlue.shade300
            : Colors.white.withValues(alpha: 0.6);
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}
