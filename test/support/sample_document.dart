import 'dart:ui';

import 'package:easy_grbl/models/layer_settings.dart';
import 'package:easy_grbl/models/operation_type.dart';
import 'package:easy_grbl/models/svg_document.dart';
import 'package:easy_grbl/models/svg_node.dart';
import 'package:easy_grbl/models/svg_node_type.dart';

/// Covers every operation and cut side; shared by the regression tests.
SvgDocument sampleDocument() {
  const square = 'M 10,10 L 40,10 L 40,40 L 10,40 Z';
  return SvgDocument(
    viewBox: const Rect.fromLTWH(0, 0, 100, 60),
    roots: [
      SvgNode(
        id: 'engrave',
        label: 'Engrave',
        type: SvgNodeType.path,
        pathData: 'M 5,50 C 20,30 40,70 60,50',
        settings: LayerSettings(
            operationType: OperationType.engrave, powerPercent: 40, speedMmS: 30),
      ),
      SvgNode(
        id: 'cut_line',
        label: 'Cut line',
        type: SvgNodeType.path,
        pathData: square,
        settings: LayerSettings(
            operationType: OperationType.cut, passes: 2, cutDepthMm: 1.5),
      ),
      SvgNode(
        id: 'cut_outer',
        label: 'Cut outer',
        type: SvgNodeType.path,
        pathData: 'M 50,10 L 80,10 L 80,40 L 50,40 Z',
        settings: LayerSettings(
            operationType: OperationType.cut,
            cutSide: CutSide.outer,
            cutDepthMm: 2.0),
      ),
      SvgNode(
        id: 'cut_inner',
        label: 'Cut inner',
        type: SvgNodeType.path,
        pathData: 'M 60,15 L 70,15 L 70,25 L 60,25 Z',
        settings: LayerSettings(
            operationType: OperationType.cut, cutSide: CutSide.inner),
      ),
      SvgNode(
        id: 'fill',
        label: 'Fill',
        type: SvgNodeType.path,
        pathData: 'M 85,5 L 95,5 L 95,15 L 85,15 Z',
        settings: LayerSettings(
            operationType: OperationType.fill, linesPerMm: 2, fillOutline: true),
      ),
    ],
  );
}

/// A negative-Fill group (with a child that has its own Cut) beside a plain
/// Fill path; small work area and coarse hatch keep the golden short.
SvgDocument negativeFillDocument() => SvgDocument(
      viewBox: const Rect.fromLTWH(0, 0, 30, 20),
      roots: [
        SvgNode(
          id: 'negative',
          label: 'Negative',
          type: SvgNodeType.group,
          transform: 'translate(2,0)',
          settings: LayerSettings(
              operationType: OperationType.fill,
              linesPerMm: 1,
              fillNegative: true),
          children: [
            SvgNode(
              id: 'square',
              label: 'Square',
              type: SvgNodeType.path,
              pathData: 'M 4,4 L 12,4 L 12,12 L 4,12 Z',
            ),
            SvgNode(
              id: 'cut_circle',
              label: 'Cut circle',
              type: SvgNodeType.circle,
              pathData: 'M 22,10 A 3,3 0 1 1 16,10 A 3,3 0 1 1 22,10 Z',
              settings: LayerSettings(operationType: OperationType.cut),
            ),
          ],
        ),
      ],
    );
