class KerfTestConfig {
  final int maxPowerPercent;
  final int speedMmMin;
  final double widthMm;
  final double lineSpacing;

  const KerfTestConfig({
    this.maxPowerPercent = 100,
    this.speedMmMin = 3000,
    this.widthMm = 10,
    this.lineSpacing = 2.0,
  });

  int get lineCount => 6;

  /// Power percentages for the 6 lines, scaled by maxPowerPercent.
  List<int> get powerLevels {
    const base = [10, 30, 50, 70, 90, 100];
    return base
        .map((p) => (p * maxPowerPercent / 100).round().clamp(0, 100))
        .toList();
  }

  KerfTestConfig copyWith({
    int? maxPowerPercent,
    int? speedMmMin,
    double? widthMm,
    double? lineSpacing,
  }) =>
      KerfTestConfig(
        maxPowerPercent: maxPowerPercent ?? this.maxPowerPercent,
        speedMmMin: speedMmMin ?? this.speedMmMin,
        widthMm: widthMm ?? this.widthMm,
        lineSpacing: lineSpacing ?? this.lineSpacing,
      );
}
