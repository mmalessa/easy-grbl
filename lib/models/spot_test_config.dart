class SpotTestConfig {
  final int powerPercent;
  final int speedMmMin;

  const SpotTestConfig({
    this.powerPercent = 60,
    this.speedMmMin = 3000,
  });

  SpotTestConfig copyWith({int? powerPercent, int? speedMmMin}) =>
      SpotTestConfig(
        powerPercent: powerPercent ?? this.powerPercent,
        speedMmMin: speedMmMin ?? this.speedMmMin,
      );
}
