import 'package:flutter/material.dart';
import '../../models/operation_type.dart';
import '../machine_mode.dart';
import '../machine_settings.dart';

class MillModeProfile extends MachineModeProfile {
  const MillModeProfile();

  @override
  String get displayName => 'CNC mill';
  @override
  String get badgeLabel => 'CNC MILL';
  @override
  IconData get icon => Icons.precision_manufacturing_outlined;
  @override
  bool get supportsTemplates => false;
  @override
  bool get showsCutDepth => true;

  // Mill feed rates are stored in mm/s.
  @override
  double defaultSpeedMmS(OperationType op, MachineSettings s) => switch (op) {
        OperationType.engrave => s.mill.engraveFeedRate,
        OperationType.cut => s.mill.cutFeedRate,
        OperationType.fill => s.mill.fillFeedRate,
        OperationType.skip => 0,
      };
}
