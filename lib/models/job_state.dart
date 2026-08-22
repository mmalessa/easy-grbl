/// Runtime job-in-progress state (streaming/animation position) — separate
/// from machine pose/status ([MachineState]) and the communication log
/// ([CommLog]).
class JobState {
  double progress = 0.0;
  int currentStep = 0;
  String currentLabel = '';
}
