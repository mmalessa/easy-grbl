import 'dart:async';
import 'dart:ui';
import '../models/svg_document.dart';
import '../models/svg_node.dart';
import '../models/operation_type.dart';
import 'grbl_service.dart';

class GrblMockService extends GrblService {
  bool _jobPaused = false;
  List<String> _jobSteps = [];
  Timer? _jobTimer;

  @override
  bool get isJobPaused => _jobPaused;

  // ── Connection ───────────────────────────────────────────────────

  void connect() {
    connected = true;
    notifyListeners();
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
    x = 0; y = 0; z = 0;
    notifyListeners();
  }

  // ── Job execution ────────────────────────────────────────────────

  @override
  void startJob(SvgDocument document) {
    if (!isIdle) return;
    _jobSteps = _collectSteps(document.roots);
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
      // Transition to idle and mark completion in one notification.
      status = MachineStatus.idle;
      jobJustCompleted = true;
      notifyListeners();
      return;
    }
    jobCurrentLabel = _jobSteps[jobCurrentStep];
    jobProgress = jobCurrentStep / _jobSteps.length;
    notifyListeners();
    _jobTimer = Timer(const Duration(milliseconds: 500), () {
      jobCurrentStep++;
      _advance();
    });
  }

  List<String> _collectSteps(List<SvgNode> roots) {
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
  // In machine coords Rect, top=minY (bottom edge), bottom=maxY (top edge).
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
