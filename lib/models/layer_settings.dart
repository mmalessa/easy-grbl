import 'operation_type.dart';

class LayerSettings {
  OperationType operationType;
  int powerPercent;
  int speedMmMin;
  int passes;

  LayerSettings({
    this.operationType = OperationType.skip,
    this.powerPercent = 80,
    this.speedMmMin = 3000,
    this.passes = 1,
  });

  LayerSettings copyWith({
    OperationType? operationType,
    int? powerPercent,
    int? speedMmMin,
    int? passes,
  }) =>
      LayerSettings(
        operationType: operationType ?? this.operationType,
        powerPercent: powerPercent ?? this.powerPercent,
        speedMmMin: speedMmMin ?? this.speedMmMin,
        passes: passes ?? this.passes,
      );
}
