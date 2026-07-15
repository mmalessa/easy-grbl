import 'operation_type.dart';

enum FillDirection { horizontal, vertical }

enum CutSide { line, inner, outer }

extension CutSideDisplay on CutSide {
  String get label => switch (this) {
        CutSide.line => 'Line',
        CutSide.inner => 'Inner',
        CutSide.outer => 'Outer',
      };
}

class LayerSettings {
  OperationType operationType;
  int powerPercent;
  double speedMmS;
  int passes;
  FillDirection fillDirection;
  double linesPerMm;
  bool fillOutline;
  CutSide cutSide;
  double cutDepthMm;

  LayerSettings({
    this.operationType = OperationType.skip,
    this.powerPercent = 80,
    this.speedMmS = 50.0,
    this.passes = 1,
    this.fillDirection = FillDirection.horizontal,
    this.linesPerMm = 10.0,
    this.fillOutline = true,
    this.cutSide = CutSide.line,
    this.cutDepthMm = 1.0,
  });

  LayerSettings copyWith({
    OperationType? operationType,
    int? powerPercent,
    double? speedMmS,
    int? passes,
    FillDirection? fillDirection,
    double? linesPerMm,
    bool? fillOutline,
    CutSide? cutSide,
    double? cutDepthMm,
  }) =>
      LayerSettings(
        operationType: operationType ?? this.operationType,
        powerPercent: powerPercent ?? this.powerPercent,
        speedMmS: speedMmS ?? this.speedMmS,
        passes: passes ?? this.passes,
        fillDirection: fillDirection ?? this.fillDirection,
        linesPerMm: linesPerMm ?? this.linesPerMm,
        fillOutline: fillOutline ?? this.fillOutline,
        cutSide: cutSide ?? this.cutSide,
        cutDepthMm: cutDepthMm ?? this.cutDepthMm,
      );
}
