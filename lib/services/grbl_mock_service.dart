import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/svg_node.dart';
import '../models/operation_type.dart';

enum MachineStatus { idle, jog, run, homing, alarm, hold }

extension MachineStatusDisplay on MachineStatus {
  String get label => switch (this) {
        MachineStatus.idle => 'IDLE',
        MachineStatus.jog => 'JOG',
        MachineStatus.run => 'RUN',
        MachineStatus.homing => 'HOME',
        MachineStatus.alarm => 'ALARM',
        MachineStatus.hold => 'HOLD',
      };

  // ignore: avoid_returning_null_for_void
  ({int r, int g, int b}) get rgb => switch (this) {
        MachineStatus.idle => (r: 56, g: 142, b: 60),
        MachineStatus.jog => (r: 25, g: 118, b: 210),
        MachineStatus.run => (r: 230, g: 119, b: 0),
        MachineStatus.homing => (r: 245, g: 177, b: 0),
        MachineStatus.alarm => (r: 211, g: 47, b: 47),
        MachineStatus.hold => (r: 230, g: 119, b: 0),
      };
}

class GrblMockService extends ChangeNotifier {
  double x = 0;
  double y = 0;
  double z = 0;
  MachineStatus status = MachineStatus.idle;
  double stepMm = 1.0;
  bool connected = false;

  // ── Job state ────────────────────────────────────────────────────
  double jobProgress = 0.0;
  int jobCurrentStep = 0;
  String jobCurrentLabel = '';
  bool _jobPaused = false;
  List<String> _jobSteps = [];
  Timer? _jobTimer;

  bool get isIdle => connected && status == MachineStatus.idle;
  bool get isJobRunning => status == MachineStatus.run;
  bool get isJobPaused => _jobPaused;

  // ── Connection ───────────────────────────────────────────────────

  void connect() {
    connected = true;
    notifyListeners();
  }

  void disconnect() {
    connected = false;
    notifyListeners();
  }

  // ── Jogging ──────────────────────────────────────────────────────

  void jog(double dx, double dy, double dz) {
    if (!isIdle) return;
    _setStatus(MachineStatus.jog);
    Future.delayed(const Duration(milliseconds: 140), () {
      x = _round(x + dx);
      y = _round(y + dy);
      z = _round(z + dz);
      _setStatus(MachineStatus.idle);
    });
  }

  void homeAll() {
    if (!connected || !isIdle) return;
    _setStatus(MachineStatus.homing);
    Future.delayed(const Duration(milliseconds: 1600), () {
      x = 0;
      y = 0;
      z = 0;
      _setStatus(MachineStatus.idle);
    });
  }

  void setOrigin() {
    if (!connected || !isIdle) return;
    x = 0;
    y = 0;
    z = 0;
    notifyListeners();
  }

  void setStep(double step) {
    stepMm = step;
    notifyListeners();
  }

  // ── Job execution ────────────────────────────────────────────────

  void startJob(List<SvgNode> roots) {
    if (!isIdle) return;
    _jobSteps = _collectJobSteps(roots);
    if (_jobSteps.isEmpty) return;
    jobProgress = 0.0;
    jobCurrentStep = 0;
    _jobPaused = false;
    _setStatus(MachineStatus.run);
    _advanceJob();
  }

  void pauseJob() {
    if (!isJobRunning || _jobPaused) return;
    _jobPaused = true;
    _jobTimer?.cancel();
    notifyListeners();
  }

  void resumeJob() {
    if (!isJobRunning || !_jobPaused) return;
    _jobPaused = false;
    _advanceJob();
  }

  void stopJob() {
    _jobTimer?.cancel();
    _jobSteps = [];
    jobProgress = 0.0;
    jobCurrentStep = 0;
    jobCurrentLabel = '';
    _jobPaused = false;
    _setStatus(MachineStatus.idle);
  }

  void _advanceJob() {
    if (jobCurrentStep >= _jobSteps.length) {
      jobProgress = 1.0;
      jobCurrentLabel = 'Complete';
      notifyListeners();
      _jobTimer = Timer(const Duration(seconds: 1), () {
        _jobSteps = [];
        jobProgress = 0.0;
        jobCurrentLabel = '';
        _setStatus(MachineStatus.idle);
      });
      return;
    }
    jobCurrentLabel = _jobSteps[jobCurrentStep];
    jobProgress = jobCurrentStep / _jobSteps.length;
    notifyListeners();
    _jobTimer = Timer(const Duration(milliseconds: 500), () {
      jobCurrentStep++;
      _advanceJob();
    });
  }

  // ── Job helpers ──────────────────────────────────────────────────

  /// Count paths and total passes for all enabled, non-skip paths.
  ({int paths, int passes}) countJobSteps(List<SvgNode> roots) {
    var paths = 0;
    var passes = 0;
    void walk(List<SvgNode> nodes, bool pe, OperationType? iop) {
      for (final n in nodes) {
        if (!n.enabled || !pe) continue;
        final own = n.settings.operationType;
        final eff = own != OperationType.skip ? own : iop;
        if (n.pathData != null && eff != null && eff != OperationType.skip) {
          paths++;
          passes += n.settings.passes;
        }
        walk(n.children, n.enabled, eff);
      }
    }
    walk(roots, true, null);
    return (paths: paths, passes: passes);
  }

  List<String> _collectJobSteps(List<SvgNode> roots) {
    final steps = <String>[];
    void walk(List<SvgNode> nodes, bool pe, OperationType? iop) {
      for (final n in nodes) {
        if (!n.enabled || !pe) continue;
        final own = n.settings.operationType;
        final eff = own != OperationType.skip ? own : iop;
        if (n.pathData != null && eff != null && eff != OperationType.skip) {
          final p = n.settings.passes;
          for (var i = 0; i < p; i++) {
            steps.add(p > 1
                ? '${eff.label}: ${n.label} (pass ${i + 1}/$p)'
                : '${eff.label}: ${n.label}');
          }
        }
        walk(n.children, n.enabled, eff);
      }
    }
    walk(roots, true, null);
    return steps;
  }

  // ── Internal ─────────────────────────────────────────────────────

  void _setStatus(MachineStatus s) {
    status = s;
    notifyListeners();
  }

  double _round(double v) => (v * 1000).roundToDouble() / 1000;

  @override
  void dispose() {
    _jobTimer?.cancel();
    super.dispose();
  }
}
