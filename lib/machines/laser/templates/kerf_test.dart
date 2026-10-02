import 'dart:ui';
import '../../../models/layer_settings.dart';
import '../../../models/operation_type.dart';
import '../../../models/svg_document.dart';
import '../../../models/svg_node.dart';
import '../../../models/svg_node_type.dart';

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

/// Preview document for the Kerf Test: one line per power level.
SvgDocument buildKerfTestDocument(KerfTestConfig cfg) {
  final powers = cfg.powerLevels;
  final nodes = <SvgNode>[];
  for (var i = 0; i < cfg.lineCount; i++) {
    final svgY = (cfg.lineCount - 1 - i) * cfg.lineSpacing.toInt();
    final pct = powers[i];
    nodes.add(SvgNode(
      id: 'line_$i',
      label: '$pct% power',
      type: SvgNodeType.path,
      pathData: 'M 0,$svgY L ${cfg.widthMm},$svgY',
      settings: LayerSettings(
        operationType: OperationType.engrave,
      ),
    ));
  }
  final h = (cfg.lineCount - 1) * cfg.lineSpacing;
  return SvgDocument(
    roots: nodes,
    viewBox: Rect.fromLTWH(0, 0, cfg.widthMm, h),
  );
}
