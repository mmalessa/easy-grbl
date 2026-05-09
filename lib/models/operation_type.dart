import 'package:flutter/material.dart';

enum OperationType { skip, engrave, cut, mark }

extension OperationTypeDisplay on OperationType {
  String get label => switch (this) {
        OperationType.skip => 'Skip',
        OperationType.engrave => 'Engrave',
        OperationType.cut => 'Cut',
        OperationType.mark => 'Mark',
      };

  Color get color => switch (this) {
        OperationType.skip => Colors.grey,
        OperationType.engrave => const Color(0xFFFF9800),
        OperationType.cut => const Color(0xFFE53935),
        OperationType.mark => const Color(0xFF43A047),
      };
}
