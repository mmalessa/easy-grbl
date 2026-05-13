class FocusTestConfig {
  final int powerPercent;
  final int speedMmMin;
  final double widthMm;
  final double lineSpacing;
  final double zStep;

  const FocusTestConfig({
    this.powerPercent = 60,
    this.speedMmMin = 3000,
    this.widthMm = 9,
    this.lineSpacing = 1.0,
    this.zStep = 0.1,
  });

  int get lineCount => (widthMm / lineSpacing).round();
  double get zRange => ((lineCount - 1) / 2).floor() * zStep;

  FocusTestConfig copyWith({
    int? powerPercent,
    int? speedMmMin,
    double? widthMm,
    double? lineSpacing,
    double? zStep,
  }) =>
      FocusTestConfig(
        powerPercent: powerPercent ?? this.powerPercent,
        speedMmMin: speedMmMin ?? this.speedMmMin,
        widthMm: widthMm ?? this.widthMm,
        lineSpacing: lineSpacing ?? this.lineSpacing,
        zStep: zStep ?? this.zStep,
      );
}
