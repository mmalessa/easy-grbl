import 'package:flutter/foundation.dart';
import '../models/svg_document.dart';
import '../models/svg_node.dart';
import '../models/operation_type.dart';
import '../models/machine_settings.dart';

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

  ({int r, int g, int b}) get rgb => switch (this) {
        MachineStatus.idle => (r: 56, g: 142, b: 60),
        MachineStatus.jog => (r: 25, g: 118, b: 210),
        MachineStatus.run => (r: 230, g: 119, b: 0),
        MachineStatus.homing => (r: 245, g: 177, b: 0),
        MachineStatus.alarm => (r: 211, g: 47, b: 47),
        MachineStatus.hold => (r: 230, g: 119, b: 0),
      };
}

typedef LogEntry = ({bool rx, String text});

abstract class GrblService extends ChangeNotifier {
  // ── Communication log ────────────────────────────────────────────
  final List<LogEntry> commLog = [];

  void logTx(String text) {
    commLog.add((rx: false, text: text));
    if (commLog.length > 500) commLog.removeAt(0);
  }

  void logRx(String text) {
    commLog.add((rx: true, text: text));
    if (commLog.length > 500) commLog.removeAt(0);
  }

  // ── Shared state ─────────────────────────────────────────────────
  MachineSettings machineSettings = const MachineSettings();
  double x = 0;
  double y = 0;
  double z = 0;
  MachineStatus status = MachineStatus.idle;
  double stepMm = 1.0;
  double stepMmZ = 1.0;
  bool connected = false;

  // ── Job state ────────────────────────────────────────────────────
  double jobProgress = 0.0;
  int jobCurrentStep = 0;
  String jobCurrentLabel = '';

  // ── Concrete getters ─────────────────────────────────────────────
  bool get isIdle => connected && status == MachineStatus.idle;
  bool get isJobRunning => status == MachineStatus.run;
  bool get isJobPaused;

  // ── Concrete helpers (shared by all implementations) ─────────────

  void setStep(double step) {
    stepMm = step;
    notifyListeners();
  }

  void setStepZ(double step) {
    stepMmZ = step;
    notifyListeners();
  }

  /// Counts enabled non-skip paths for the UI summary.
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

  void setMachineStatus(MachineStatus s) {
    status = s;
    notifyListeners();
  }

  // ── Abstract operations ──────────────────────────────────────────
  void disconnect();
  void jog(double dx, double dy, double dz);
  void homeAll();
  void setOrigin();
  void startJob(SvgDocument document);
  void pauseJob();
  void resumeJob();
  void stopJob();
}
