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

/// Runtime machine pose/status/jog-step — separate from the communication
/// log ([CommLog]) and job-in-progress state ([JobState]).
class MachineState {
  double x = 0;
  double y = 0;
  double z = 0;
  MachineStatus status = MachineStatus.idle;
  double stepMm = 10.0;
  double stepMmZ = 0.1;
  bool connected = false;
}
