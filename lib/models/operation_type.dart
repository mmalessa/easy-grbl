enum OperationType { skip, engrave, cut, mark }

extension OperationTypeLabel on OperationType {
  String get label => switch (this) {
        OperationType.skip => 'Skip',
        OperationType.engrave => 'Engrave',
        OperationType.cut => 'Cut',
        OperationType.mark => 'Mark',
      };
}
