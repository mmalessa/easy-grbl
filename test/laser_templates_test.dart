import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:easy_grbl/machines/laser/templates/focus_test.dart';
import 'package:easy_grbl/machines/laser/templates/kerf_test.dart';
import 'package:easy_grbl/machines/laser/templates/spot_test.dart';
import 'package:easy_grbl/models/operation_type.dart';

void main() {
  test('focus test document: middle line is Z=0 and cut', () {
    final doc = buildFocusTestDocument(const FocusTestConfig());
    expect(doc.roots.length, 9);
    expect(doc.roots[4].label, 'Z=0.0');
    expect(doc.roots[4].settings.operationType, OperationType.cut);
    expect(doc.roots[0].settings.operationType, OperationType.engrave);
    expect(doc.viewBox, const Rect.fromLTWH(0, 0, 9, 8));
  });

  test('kerf test document: one line per power level', () {
    final doc = buildKerfTestDocument(const KerfTestConfig());
    expect(doc.roots.map((n) => n.label).toList(), [
      '10% power', '30% power', '50% power', '70% power', '90% power', '100% power',
    ]);
    expect(doc.viewBox, const Rect.fromLTWH(0, 0, 10, 10));
  });

  test('spot test document: three bands', () {
    final doc = buildSpotTestDocument();
    expect(doc.roots.map((n) => n.label).toList(), ['−0.1 mm', 'exact', '+0.1 mm']);
    expect(doc.viewBox, const Rect.fromLTWH(0, 0, 9, 9));
  });
}
