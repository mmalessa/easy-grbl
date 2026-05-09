import 'package:flutter/material.dart';

enum OperationType { skip, engrave, cut }

extension OperationTypeDisplay on OperationType {
  String get label => switch (this) {
        OperationType.skip => 'Skip',
        OperationType.engrave => 'Engrave',
        OperationType.cut => 'Cut',
      };

  Color get color => switch (this) {
        OperationType.skip => Colors.grey,
        OperationType.engrave => const Color(0xFFFF9800),
        OperationType.cut => const Color(0xFFE53935),
      };
}
