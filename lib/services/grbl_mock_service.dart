import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:path_drawing/path_drawing.dart';
import '../models/svg_document.dart';
import '../models/svg_node.dart';
import '../models/operation_type.dart';
import 'affine.dart';
import 'grbl_service.dart';

// label is empty for rapid-move steps (cursor jumps to path start without
// updating the displayed label).
typedef _Step = ({String label, double x, double y});

class GrblMockService extends GrblService {
  bool _jobPaused = false;
  List<_Step> _jobSteps = [];
  Timer? _jobTimer;

  @override
  bool get isJobPaused => _jobPaused;

  // ── Connection ───────────────────────────────────────────────────

  void connect() {
    // Simulate GRBL handshake + version string
    Future.delayed(const Duration(milliseconds: 320), () {
      connected = true;
      notifyListeners();
    });
  }

  @override
  void disconnect() {
    connected = false;
    notifyListeners();
  }

  // ── Jogging ──────────────────────────────────────────────────────

  @override
  void jog(double dx, double dy, double dz) {
    if (!isIdle) return;
    setMachineStatus(MachineStatus.jog);
    Future.delayed(const Duration(milliseconds: 140), () {
      x = _round(x + dx);
      y = _round(y + dy);
      z = _round(z + dz);
      setMachineStatus(MachineStatus.idle);
    });
  }

  @override
  void homeAll() {
    if (!isIdle) return;
    setMachineStatus(MachineStatus.homing);
    Future.delayed(const Duration(milliseconds: 1600), () {
      x = 0; y = 0; z = 0;
      setMachineStatus(MachineStatus.idle);
    });
  }

  @override
  void setOrigin() {
    if (!isIdle) return;
    // Simulate G92/G10 round-trip
    Future.delayed(const Duration(milliseconds: 60), () {
      x = 0; y = 0; z = 0;
      notifyListeners();
    });
  }

  // ── Job execution ────────────────────────────────────────────────

  @override
  void startJob(SvgDocument document) {
    if (!isIdle) return;
    _jobSteps = _collectSteps(document);
    if (_jobSteps.isEmpty) return;
    jobProgress = 0.0;
    jobCurrentStep = 0;
    _jobPaused = false;
    setMachineStatus(MachineStatus.run);
    _advance();
  }

  @override
  void pauseJob() {
    if (!isJobRunning || _jobPaused) return;
    _jobPaused = true;
    _jobTimer?.cancel();
    notifyListeners();
  }

  @override
  void resumeJob() {
    if (!isJobRunning || !_jobPaused) return;
    _jobPaused = false;
    _advance();
  }

  @override
  void stopJob() {
    _jobTimer?.cancel();
    _jobSteps = [];
    jobProgress = 0.0;
    jobCurrentStep = 0;
    jobCurrentLabel = '';
    _jobPaused = false;
    setMachineStatus(MachineStatus.idle);
  }

  void _advance() {
    if (jobCurrentStep >= _jobSteps.length) {
      _jobSteps = [];
      jobProgress = 0.0;
      jobCurrentStep = 0;
      jobCurrentLabel = '';
      _jobPaused = false;
      status = MachineStatus.idle;
      jobJustCompleted = true;
      notifyListeners();
      return;
    }
    final step = _jobSteps[jobCurrentStep];
    // Only update the displayed label on feed-move steps, not rapid moves.
    if (step.label.isNotEmpty) jobCurrentLabel = step.label;
    jobProgress = jobCurrentStep / _jobSteps.length;
    x = step.x;
    y = step.y;
    notifyListeners();
    _jobTimer = Timer(const Duration(milliseconds: 40), () {
      jobCurrentStep++;
      _advance();
    });
  }

  // ── Step collection ───────────────────────────────────────────────

  List<_Step> _collectSteps(SvgDocument doc) {
    final steps = <_Step>[];

    void walk(List<SvgNode> nodes, bool pe, OperationType? iop, SvgAffine pm) {
      for (final n in nodes) {
        if (!n.enabled || !pe) continue;
        final m = pm.multiply(SvgAffine.fromSvgString(n.transform));
        final own = n.settings.operationType;
        final eff = own != OperationType.skip ? own : iop;
        if (n.pathData != null && eff != null && eff != OperationType.skip) {
          final passes = n.settings.passes;
          for (var pass = 0; pass < passes; pass++) {
            final pts = _samplePath(n.pathData!, m, doc.viewBox);
            if (pts.isEmpty) continue;
            // Rapid move to start of path (no label — cursor jumps silently)
            steps.add((label: '', x: pts.first.dx, y: pts.first.dy));
            final label = passes > 1
                ? '${eff.label}: ${n.label} (pass ${pass + 1}/$passes)'
                : '${eff.label}: ${n.label}';
            for (final pt in pts) {
              steps.add((label: label, x: pt.dx, y: pt.dy));
            }
          }
        }
        walk(n.children, n.enabled, eff, m);
      }
    }

    walk(doc.roots, true, null, SvgAffine.identity);
    return steps;
  }

  // Sample ~20 evenly-spaced points from all contours of a path, transformed
  // to machine coordinates (origin at bottom-left, Y-up).
  List<Offset> _samplePath(String pathData, SvgAffine xform, Rect vb) {
    try {
      final path = parseSvgPathData(pathData);
      final metrics = path.computeMetrics().toList();
      if (metrics.isEmpty) return [];

      const totalPoints = 20;
      final perContour = math.max(3, totalPoints ~/ math.max(1, metrics.length));
      final pts = <Offset>[];

      for (final metric in metrics) {
        for (var i = 0; i <= perContour; i++) {
          final d = metric.length * i / perContour;
          final t = metric.getTangentForOffset(d);
          if (t != null) {
            final tp = xform.apply(t.position);
            pts.add(Offset(tp.dx - vb.left, vb.bottom - tp.dy));
          }
        }
      }
      return pts;
    } catch (_) {
      return [];
    }
  }

  // ── Framing ──────────────────────────────────────────────────────

  @override
  void startFraming(Rect b) {
    if (isFraming || isJobRunning) return;
    isFraming = true;
    notifyListeners();
    _doFraming(b);
  }

  @override
  void stopFraming() {
    if (!isFraming) return;
    isFraming = false;
    notifyListeners();
  }

  // Corners: bottom-left → bottom-right → top-right → top-left → back.
  void _doFraming(Rect b) async {
    final corners = [
      Offset(b.left, b.top),
      Offset(b.right, b.top),
      Offset(b.right, b.bottom),
      Offset(b.left, b.bottom),
      Offset(b.left, b.top),
    ];
    for (final c in corners) {
      if (!isFraming) return;
      await Future.delayed(const Duration(milliseconds: 350));
      if (!isFraming) return;
      x = c.dx;
      y = c.dy;
      notifyListeners();
    }
    isFraming = false;
    notifyListeners();
  }

  double _round(double v) => (v * 1000).roundToDouble() / 1000;

  @override
  void dispose() {
    _jobTimer?.cancel();
    super.dispose();
  }
}
