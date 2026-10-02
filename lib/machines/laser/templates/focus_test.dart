import 'dart:ui';
import '../../../models/layer_settings.dart';
import '../../../models/operation_type.dart';
import '../../../models/svg_document.dart';
import '../../../models/svg_node.dart';
import '../../../models/svg_node_type.dart';

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

/// Preview document for the Focus Test: one line per Z step, the Z=0 line
/// marked as Cut so it stands out.
SvgDocument buildFocusTestDocument(FocusTestConfig cfg) {
  final nodes = <SvgNode>[];
  final half = ((cfg.lineCount - 1) / 2).floor();
  for (var i = 0; i < cfg.lineCount; i++) {
    final svgY = (cfg.lineCount - 1) - i;
    final z = (i - half) * cfg.zStep;
    nodes.add(SvgNode(
      id: 'line_$i',
      label: 'Z=${z.toStringAsFixed(1)}',
      type: SvgNodeType.path,
      pathData: 'M 0,$svgY L ${cfg.widthMm},$svgY',
      settings: LayerSettings(
        operationType: z == 0 ? OperationType.cut : OperationType.engrave,
      ),
    ));
  }
  final h = cfg.lineCount - 1.0;
  return SvgDocument(
    roots: nodes,
    viewBox: Rect.fromLTWH(0, 0, cfg.widthMm, h),
  );
}
