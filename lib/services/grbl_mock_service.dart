import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/scheduler.dart';
import 'package:path_drawing/path_drawing.dart';
import '../models/svg_document.dart';
import '../models/layer_settings.dart';
import '../machines/gcode/gcode_strategy.dart';
import '../machines/machine_mode.dart';
import '../models/operation_type.dart';
import '../geometry/affine.dart';
import 'gcode_format.dart';
import '../geometry/fill_lines.dart';
import 'grbl_service.dart';
import '../geometry/path_offset.dart';
import '../geometry/svg_node_walker.dart';

// label is empty for rapid-move steps (cursor jumps to path start without
// updating the displayed label).
typedef _Step = ({String label, double x, double y});

class GrblMockService extends GrblService {
  bool _jobPaused = false;
  bool _disposed = false;
  List<_Step> _jobSteps = [];
  Timer? _jobTimer;
  String _prevStepLabel = '';

  @override
  bool get isJobPaused => _jobPaused;

  // ── Connection ───────────────────────────────────────────────────

  @override
  bool get isMock => true;

  void connect() {
    if (connected) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_disposed || connected) return;
      logRx("Grbl 1.1h ['\$' for help]");
      logRx("[MSG:'\$H'|'\$X' to unlock]");
      connected = true;
      notifyListeners();
    });
  }

  @override
  void disconnect() {
    connected = false;
    notifyListeners();
  }

  // Simulated firmware state, separate from the app-side machineSettings
  // so mismatches can be reproduced/tested. Defaults to the app's current
  // machine type the first time it's queried after connecting.
  MachineType? _mockDeviceType;

  @override
  Future<MachineType?> queryMachineType() async {
    if (!connected || isJobActive) return null;
    _mockDeviceType ??= machineSettings.machineType;
    return _mockDeviceType;
  }

  @override
  Future<bool> setDeviceLaserMode(bool enabled) async {
    if (!connected || isJobActive) return false;
    _mockDeviceType = enabled ? MachineType.laser : MachineType.mill;
    return true;
  }

  // ── Jogging ──────────────────────────────────────────────────────

  @override
  void jog(double dx, double dy, double dz) {
    if (!isIdle) return;
    final cmd = '\$J=G91G21'
        '${dx != 0 ? 'X${formatGcodeNumber(dx)}' : ''}'
        '${dy != 0 ? 'Y${formatGcodeNumber(dy)}' : ''}'
        '${dz != 0 ? 'Z${formatGcodeNumber(dz)}' : ''}'
        'F3000';
    logTx(cmd);
    setMachineStatus(MachineStatus.jog);
    Future.delayed(const Duration(milliseconds: 140), () {
      if (_disposed) return;
      if (status != MachineStatus.jog) return;
      x = _round(x + dx);
      y = _round(y + dy);
      z = _round(z + dz);
      logRx('ok');
      setMachineStatus(MachineStatus.idle);
    });
  }

  @override
  void homeAll() {
    if (!connected) return;
    _jobTimer?.cancel();
    logTx('G0 X0 Y0 Z0');
    setMachineStatus(MachineStatus.run);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (_disposed) return;
      x = 0; y = 0; z = 0;
      logRx('ok');
      setMachineStatus(MachineStatus.idle);
    });
  }

  @override
  void setOrigin() {
    if (!isIdle) return;
    logTx('G10 L20 P1 X0 Y0 Z0');
    logRx('ok');
    x = 0; y = 0; z = 0;
    notifyListeners();
  }

  // ── Job execution ────────────────────────────────────────────────

  @override
  void startJob(SvgDocument document) {
    if (!isIdle) return;
    _jobSteps = _collectSteps(document);
    if (_jobSteps.isEmpty) return;

    logTx('G21'); logRx('ok');
    logTx('G90'); logRx('ok');
    logTx('M5 S0'); logRx('ok');
    logTx('G0 X0.000 Y0.000'); logRx('ok');

    jobProgress = 0.0;
    jobCurrentStep = 0;
    _jobPaused = false;
    _prevStepLabel = '';
    setMachineStatus(MachineStatus.run);
    _advance();
  }

  @override
  void startLines(List<String> lines) {
    if (!isIdle || lines.isEmpty) return;
    logTx('; --- focus test ---');
    for (final line in lines) {
      logTx(line);
    }
    logRx('ok');
    jobProgress = 0.0;
    jobCurrentStep = 0;
    jobCurrentLabel = '';
    setMachineStatus(MachineStatus.run);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_disposed) return;
      jobProgress = 0.0;
      jobCurrentLabel = '';
      setMachineStatus(MachineStatus.idle);
    });
  }

  @override
  void pauseJob() {
    if (!isJobRunning || _jobPaused) return;
    _jobPaused = true;
    _jobTimer?.cancel();
    logTx('!');
    logRx('ok');
    notifyListeners();
  }

  @override
  void resumeJob() {
    if (!isJobRunning || !_jobPaused) return;
    _jobPaused = false;
    logTx('~');
    logRx('ok');
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
    _prevStepLabel = '';
    logTx('\x18'); // Ctrl-X soft-reset
    logRx("Grbl 1.1h ['\$' for help]");
    logTx('\$X');
    logRx('ok');
    setMachineStatus(MachineStatus.idle);
  }

  void _advance() {
    if (jobCurrentStep >= _jobSteps.length) {
      logTx('M5 S0'); logRx('ok');
      logTx('G0 X0.000 Y0.000'); logRx('ok');
      logTx('M2'); logRx('ok');
      _jobSteps = [];
      jobProgress = 0.0;
      jobCurrentStep = 0;
      jobCurrentLabel = '';
      _jobPaused = false;
      _prevStepLabel = '';
      x = 0; y = 0; z = 0;
      setMachineStatus(MachineStatus.idle);
      return;
    }

    final step = _jobSteps[jobCurrentStep];

    if (step.label.isNotEmpty && step.label != _prevStepLabel) {
      // New path — log header + rapid + laser-on
      _prevStepLabel = step.label;
      logTx('; --- ${step.label} ---');
      logTx('G0 X${formatGcodeNumber(step.x)} Y${formatGcodeNumber(step.y)}'); logRx('ok');
      logTx('M3 S500'); logRx('ok');
    } else if (step.label.isNotEmpty && jobCurrentStep % 6 == 0) {
      // Sample every 6th feed-move to keep log readable
      logTx('G1 X${formatGcodeNumber(step.x)} Y${formatGcodeNumber(step.y)} F1000'); logRx('ok');
    }

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
    final strategy = GcodeStrategy.of(machineSettings);

    walkSvgNodes(doc.roots, (n, m, eff, effSettings) {
      if (!isActiveOp(n.pathData, eff)) return;
      final op = eff!;
      final passes = effectivePassesFor(op, effSettings);
      for (var pass = 0; pass < passes; pass++) {
        final pts = op == OperationType.fill
            ? _sampleFill(n.pathData!, m, doc.viewBox, effSettings,
                strategy.fillInset(effSettings))
            : _samplePath(n.pathData!, m, doc.viewBox,
                offsetDeltaMm: op == OperationType.cut
                    ? strategy.cutOffsetDelta(effSettings)
                    : 0.0);
        if (pts.isEmpty) continue;
        final label = passes > 1
            ? '${op.label}: ${n.label} (pass ${pass + 1}/$passes)'
            : '${op.label}: ${n.label}';
        if (op == OperationType.fill) {
          // Each pair of pts is one scanline: rapid to start, feed to end
          for (var i = 0; i < pts.length - 1; i += 2) {
            steps.add((label: '', x: pts[i].dx, y: pts[i].dy));
            steps.add((label: label, x: pts[i].dx, y: pts[i].dy));
            steps.add((label: label, x: pts[i + 1].dx, y: pts[i + 1].dy));
          }
          // Outline pass after fill
          if (effSettings.fillOutline) {
            final outline = _samplePath(n.pathData!, m, doc.viewBox);
            if (outline.isNotEmpty) {
              final outlineLabel = 'Fill outline: ${n.label}';
              steps.add((label: '', x: outline.first.dx, y: outline.first.dy));
              for (final pt in outline) {
                steps.add((label: outlineLabel, x: pt.dx, y: pt.dy));
              }
            }
          }
        } else {
          steps.add((label: '', x: pts.first.dx, y: pts.first.dy));
          for (final pt in pts) {
            steps.add((label: label, x: pt.dx, y: pt.dy));
          }
        }
      }
    });

    return steps;
  }

  // Sample ~20 evenly-spaced points from all contours of a path, transformed
  // to machine coordinates (origin at bottom-left, Y-up). Each contour is
  // offset independently (for Cut) before being flattened into one list.
  List<Offset> _samplePath(String pathData, SvgAffine xform, Rect vb,
      {double offsetDeltaMm = 0.0}) {
    try {
      final path = parseSvgPathData(pathData);
      final metrics = path.computeMetrics().toList();
      if (metrics.isEmpty) return [];

      const totalPoints = 20;
      final perContour = math.max(3, totalPoints ~/ math.max(1, metrics.length));
      final pts = <Offset>[];

      for (final metric in metrics) {
        var contourPts = <Offset>[];
        for (var i = 0; i <= perContour; i++) {
          final d = metric.length * i / perContour;
          final t = metric.getTangentForOffset(d);
          if (t != null) {
            final tp = xform.apply(t.position);
            contourPts.add(Offset(tp.dx - vb.left, vb.bottom - tp.dy));
          }
        }
        if (offsetDeltaMm != 0) {
          contourPts = PathOffset.offsetClosedContour(contourPts, offsetDeltaMm);
        }
        pts.addAll(contourPts);
      }
      return pts;
    } catch (_) {
      return [];
    }
  }

  // Returns [start, end, start, end, ...] pairs in machine coords for fill lines.
  // Subsamples to at most 60 lines so the animation doesn't run for too long.
  List<Offset> _sampleFill(
    String pathData,
    SvgAffine xform,
    Rect vb,
    LayerSettings settings,
    double inset,
  ) {
    try {
      final rawPath = parseSvgPathData(pathData);
      final path = rawPath.transform(xform.toFloat64());
      var lines = computeFillLines(
          path, settings.fillDirection, settings.linesPerMm, inset: inset);
      if (lines.isEmpty) return [];

      const maxLines = 60;
      if (lines.length > maxLines) {
        final stride = lines.length / maxLines;
        lines = [
          for (var i = 0.0; i < lines.length; i += stride) lines[i.toInt()]
        ];
      }

      final pts = <Offset>[];
      for (final line in lines) {
        pts.add(Offset(line.$1.dx - vb.left, vb.bottom - line.$1.dy));
        pts.add(Offset(line.$2.dx - vb.left, vb.bottom - line.$2.dy));
      }
      return pts;
    } catch (_) {
      return [];
    }
  }

  double _round(double v) => (v * 1000).roundToDouble() / 1000;

  @override
  void dispose() {
    _disposed = true;
    _jobTimer?.cancel();
    super.dispose();
  }
}
