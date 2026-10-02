import 'dart:ui';
import '../../../models/layer_settings.dart';
import '../../../models/operation_type.dart';
import '../../../models/svg_document.dart';
import '../../../models/svg_node.dart';
import '../../../models/svg_node_type.dart';

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

/// Preview document for the Spot Size Test: three 3 mm bands of a 9 mm
/// square. Its geometry doesn't depend on the config.
SvgDocument buildSpotTestDocument() {
  const labels = ['−0.1 mm', 'exact', '+0.1 mm'];
  const bandH = 3.0;
  const w = 9.0;
  final h = bandH * 3;
  final nodes = <SvgNode>[];
  for (var i = 0; i < 3; i++) {
    final svgY = (2 - i) * bandH;
    nodes.add(SvgNode(
      id: 'band_$i',
      label: labels[i],
      type: SvgNodeType.path,
      pathData:
          'M 0,$svgY L $w,$svgY L $w,${svgY + bandH} L 0,${svgY + bandH} Z',
      settings: LayerSettings(operationType: OperationType.engrave),
    ));
  }
  return SvgDocument(
    roots: nodes,
    viewBox: Rect.fromLTWH(0, 0, w, h),
  );
}
