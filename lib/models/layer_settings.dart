import 'operation_type.dart';

enum FillDirection { horizontal, vertical }

class LayerSettings {
  OperationType operationType;
  int powerPercent;
  int speedMmMin;
  int passes;
  FillDirection fillDirection;
  double linesPerMm;

  LayerSettings({
    this.operationType = OperationType.skip,
    this.powerPercent = 80,
    this.speedMmMin = 3000,
    this.passes = 1,
    this.fillDirection = FillDirection.horizontal,
    this.linesPerMm = 10.0,
  });

  LayerSettings copyWith({
    OperationType? operationType,
    int? powerPercent,
    int? speedMmMin,
    int? passes,
    FillDirection? fillDirection,
    double? linesPerMm,
  }) =>
      LayerSettings(
        operationType: operationType ?? this.operationType,
        powerPercent: powerPercent ?? this.powerPercent,
        speedMmMin: speedMmMin ?? this.speedMmMin,
        passes: passes ?? this.passes,
        fillDirection: fillDirection ?? this.fillDirection,
        linesPerMm: linesPerMm ?? this.linesPerMm,
      );
}
