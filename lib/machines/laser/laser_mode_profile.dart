import 'package:flutter/material.dart';
import '../../models/operation_type.dart';
import '../machine_mode.dart';
import '../machine_settings.dart';

class LaserModeProfile extends MachineModeProfile {
  const LaserModeProfile();

  @override
  String get displayName => 'Laser engraver';
  @override
  String get badgeLabel => 'LASER ENGRAVER';
  @override
  IconData get icon => Icons.flare;
  @override
  bool get supportsTemplates => true;
  @override
  bool get showsCutDepth => false;

  // Laser defaults are stored in mm/min.
  @override
  double defaultSpeedMmS(OperationType op, MachineSettings s) => switch (op) {
        OperationType.engrave => s.laser.engraveSpeed / 60.0,
        OperationType.cut => s.laser.cutSpeed / 60.0,
        OperationType.fill => s.laser.fillSpeed / 60.0,
        OperationType.skip => 0,
      };
}
