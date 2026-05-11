import 'package:flutter/material.dart';

enum OperationType { skip, engrave, cut, fill }

extension OperationTypeDisplay on OperationType {
  String get label => switch (this) {
        OperationType.skip => 'Skip',
        OperationType.engrave => 'Engrave',
        OperationType.cut => 'Cut',
        OperationType.fill => 'Fill',
      };

  Color get color => switch (this) {
        OperationType.skip => Colors.grey,
        OperationType.engrave => const Color(0xFFFF9800),
        OperationType.cut => const Color(0xFFE53935),
        OperationType.fill => const Color(0xFF7B1FA2),
      };
}
