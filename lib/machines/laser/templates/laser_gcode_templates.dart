import '../laser_settings.dart';
import 'focus_test.dart';
import 'kerf_test.dart';
import 'spot_test.dart';
import '../../../services/gcode_format.dart';

class LaserGcodeTemplates {
  /// Focus Test — horizontal lines at varying Z heights.
  ///
  /// Middle line at Z=0. Lines above at Z+step … +Zmax,
  /// lines below at Z−step … −Zmax.
  /// The user inspects which line is sharpest to set correct focus.
  static String focusTest(FocusTestConfig cfg, LaserSettings s) {
    final buf = StringBuffer();
    final smax = s.sMax;
    final sVal =
        (cfg.powerPercent / 100.0 * smax).round().clamp(0, smax);
    final half = ((cfg.lineCount - 1) / 2).floor();

    buf
      ..writeln('; Focus Test — EasyGRBL')
      ..writeln('; ${cfg.lineCount} horizontal lines × ${cfg.widthMm.toStringAsFixed(0)} mm long')
      ..writeln('; Spacing: ${cfg.lineSpacing.toStringAsFixed(1)} mm')
      ..writeln('; Z step: ${cfg.zStep.toStringAsFixed(2)} mm')
      ..writeln('; Power: ${cfg.powerPercent}%  (S$sVal / S$smax)')
      ..writeln('; Speed: ${cfg.speedMmMin} mm/min')
      ..writeln()
      ..writeln('G21 ; metric')
      ..writeln('G90 ; absolute')
      ..writeln('M5 S0 ; laser off')
      ..writeln('G0 X0 Y0 ; HOME')
      ..writeln();

    for (var i = 0; i < cfg.lineCount; i++) {
      final y = i;
      final z = (i - half) * cfg.zStep;
      buf
        ..writeln('; line Y=$y  Z=${z.toStringAsFixed(2)}')
        ..writeln('G0 X0 Y$y')
        ..writeln('G0 Z${z.toStringAsFixed(2)}')
        ..writeln('${s.laserMode.gcode} S$sVal')
        ..writeln('G1 X${cfg.widthMm.toStringAsFixed(0)} F${cfg.speedMmMin}')
        ..writeln('M5')
        ..writeln();
    }

    buf
      ..writeln('G0 X0 Y0 Z0 ; HOME')
      ..writeln('M5 S0')
      ..writeln('; End of Focus Test');

    return buf.toString();
  }

  /// Kerf Test — horizontal lines at increasing power levels.
  ///
  /// Lines at increasing power percentages.
  /// The user measures the burn width to determine kerf vs. power.
  static String kerfTest(KerfTestConfig cfg, LaserSettings s) {
    final buf = StringBuffer();
    final smax = s.sMax;
    final speed = cfg.speedMmMin;
    final powers = cfg.powerLevels;
    final maxPct = cfg.maxPowerPercent;

    buf
      ..writeln('; Kerf Test — EasyGRBL')
      ..writeln('; ${cfg.lineCount} horizontal lines × ${cfg.widthMm.toStringAsFixed(0)} mm long')
      ..writeln('; Spacing: ${cfg.lineSpacing.toStringAsFixed(0)} mm')
      ..writeln('; Power ramp: ${powers.join("%, ")}%  (max $maxPct%)')
      ..writeln('; Speed: $speed mm/min')
      ..writeln()
      ..writeln('G21 ; metric')
      ..writeln('G90 ; absolute')
      ..writeln('M5 S0 ; laser off')
      ..writeln('G0 X0 Y0 ; HOME')
      ..writeln();

    for (var i = 0; i < powers.length; i++) {
      final pct = powers[i];
      final sVal = (pct / 100.0 * smax).round().clamp(0, smax);
      final y = i * cfg.lineSpacing.toInt();

      buf
        ..writeln('; $pct% power  (S$sVal)')
        ..writeln('G0 X0 Y$y')
        ..writeln('G0 Z0')
        ..writeln('${s.laserMode.gcode} S$sVal')
        ..writeln('G1 X${cfg.widthMm.toStringAsFixed(0)} F$speed')
        ..writeln('M5')
        ..writeln();
    }

    buf
      ..writeln('G0 X0 Y0 Z0 ; HOME')
      ..writeln('M5 S0')
      ..writeln('; End of Kerf Test');

    return buf.toString();
  }

  /// Spot Size Test — 9×9 mm square with 3 horizontal bands.
  ///
  /// Each band is filled with horizontal lines at a different spacing:
  ///   Bottom: laserSpotSize − 0.1 mm
  ///   Middle: laserSpotSize (exact)
  ///   Top:    laserSpotSize + 0.1 mm
  /// The user inspects which band looks best-filled to verify the spot size.
  static String spotTest(SpotTestConfig cfg, LaserSettings s) {
    final buf = StringBuffer();
    final smax = s.sMax;
    final spotSize = s.laserSpotSize;
    final sVal =
        (cfg.powerPercent / 100.0 * smax).round().clamp(0, smax);
    const squareSize = 9.0;
    const bandH = 3.0;
    final spacings = [
      (spotSize - 0.1).clamp(0.01, double.infinity),
      spotSize,
      spotSize + 0.1,
    ];
    const labels = ['−0.1 mm', 'exact', '+0.1 mm'];

    buf
      ..writeln('; Spot Size Test — EasyGRBL')
      ..writeln('; 9 × 9 mm square, 3 horizontal bands')
      ..writeln('; Laser spot: ${spotSize.toStringAsFixed(2)} mm')
      ..writeln('; Power: ${cfg.powerPercent}%  (S$sVal / S$smax)')
      ..writeln('; Speed: ${cfg.speedMmMin} mm/min')
      ..writeln()
      ..writeln('G21 ; metric')
      ..writeln('G90 ; absolute')
      ..writeln('M5 S0 ; laser off')
      ..writeln('G0 X0 Y0 ; HOME')
      ..writeln();

    for (var band = 0; band < 3; band++) {
      final spacing = spacings[band];
      final y0 = band * bandH;
      final y1 = y0 + bandH;
      buf
        ..writeln('; Band ${band + 1} — ${labels[band]}  spacing=${spacing.toStringAsFixed(3)} mm')
        ..writeln();

      var ltr = true;
      var y = y0;
      while (y < y1 - 0.001) {
        final x0 = ltr ? 0.0 : squareSize;
        final x1 = ltr ? squareSize : 0.0;
        buf
          ..writeln('G0 X${formatGcodeNumber(x0)} Y${formatGcodeNumber(y)}')
          ..writeln('${s.laserMode.gcode} S$sVal')
          ..writeln('G1 X${formatGcodeNumber(x1)} F${cfg.speedMmMin}')
          ..writeln('M5');
        y += spacing;
        ltr = !ltr;
      }
      buf.writeln();
    }

    buf
      ..writeln('G0 X0 Y0 Z0 ; HOME')
      ..writeln('M5 S0')
      ..writeln('; End of Spot Size Test');

    return buf.toString();
  }
}
