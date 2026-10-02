import 'package:flutter/foundation.dart';
import '../models/svg_document.dart';
import '../machines/machine_settings.dart';
import '../machines/machine_mode.dart';
import '../models/machine_state.dart';
import '../models/job_state.dart';
import 'comm_log.dart';

export '../models/machine_state.dart' show MachineStatus, MachineStatusDisplay;
export 'comm_log.dart' show LogEntry;

/// Base class for GRBL connections (mock/serial). Composes the four
/// concerns a device connection needs to track — communication log
/// ([CommLog]), machine pose/status ([MachineState]), job-in-progress state
/// ([JobState]), and machine configuration ([MachineSettings]) — behind the
/// same flat, `ChangeNotifier`-friendly API the UI already consumes.
abstract class GrblService extends ChangeNotifier {
  // ── Communication log ────────────────────────────────────────────
  late final CommLog _log = CommLog(notifyListeners);
  List<LogEntry> get commLog => _log.entries;

  void logTx(String text) => _log.tx(text);
  void logRx(String text) => _log.rx(text);

  // ── Machine state (pose/status/jog-step) ──────────────────────────
  final MachineState _machine = MachineState();
  double get x => _machine.x;
  set x(double v) => _machine.x = v;
  double get y => _machine.y;
  set y(double v) => _machine.y = v;
  double get z => _machine.z;
  set z(double v) => _machine.z = v;
  MachineStatus get status => _machine.status;
  set status(MachineStatus v) => _machine.status = v;
  double get stepMm => _machine.stepMm;
  set stepMm(double v) => _machine.stepMm = v;
  double get stepMmZ => _machine.stepMmZ;
  set stepMmZ(double v) => _machine.stepMmZ = v;
  bool get connected => _machine.connected;
  set connected(bool v) => _machine.connected = v;

  // ── Machine configuration ──────────────────────────────────────────
  MachineSettings machineSettings = const MachineSettings();

  // ── Job state ────────────────────────────────────────────────────
  final JobState _job = JobState();
  double get jobProgress => _job.progress;
  set jobProgress(double v) => _job.progress = v;
  int get jobCurrentStep => _job.currentStep;
  set jobCurrentStep(int v) => _job.currentStep = v;
  String get jobCurrentLabel => _job.currentLabel;
  set jobCurrentLabel(String v) => _job.currentLabel = v;

  // ── Concrete getters ─────────────────────────────────────────────
  bool get isIdle => connected && status == MachineStatus.idle;
  bool get isJobRunning => status == MachineStatus.run;
  bool get isMock => false;
  bool get isJobPaused;

  /// A job is streaming or paused mid-stream — extra commands (e.g. `$$`)
  /// would steal its acks.
  bool get isJobActive => isJobRunning || isJobPaused;

  // ── Concrete helpers (shared by all implementations) ─────────────

  void setStep(double step) {
    stepMm = step;
    notifyListeners();
  }

  void setStepZ(double step) {
    stepMmZ = step;
    notifyListeners();
  }

  void setMachineStatus(MachineStatus s) {
    status = s;
    notifyListeners();
  }

  /// Queries the connected device for its actual configured machine type
  /// (laser vs. mill), independent of the app-side [machineSettings].
  /// Returns null if not connected or the device didn't report it.
  Future<MachineType?> queryMachineType() async => null;

  /// Writes the device's GRBL $32 laser-mode flag. Returns true on ack.
  Future<bool> setDeviceLaserMode(bool enabled) async => false;

  // ── Abstract operations ──────────────────────────────────────────
  void disconnect();
  void jog(double dx, double dy, double dz);
  void homeAll();
  void setOrigin();
  void startJob(SvgDocument document);
  void startLines(List<String> lines);
  void pauseJob();
  void resumeJob();
  void stopJob();
}
