import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:easy_grbl/geometry/contour_sampler.dart';
import 'package:easy_grbl/geometry/fill_lines.dart';
import 'package:easy_grbl/models/layer_settings.dart';

void main() {
  group('sampleContours', () {
    test('samples every step plus the end, without duplicates', () {
      final c = sampleContours('M 0,0 L 1,0',
          step: 0.5, minDistSq: 1e-6, map: (p) => p);
      expect(c, [
        [const Offset(0, 0), const Offset(0.5, 0), const Offset(1, 0)],
      ]);
    });

    test('applies the mapping', () {
      final c = sampleContours('M 0,0 L 1,0',
          step: 1, minDistSq: 1e-6, map: (p) => Offset(p.dx + 10, -p.dy));
      expect(c.single.first, const Offset(10, 0));
    });

    test('one list per contour; unparseable data yields none', () {
      final two = sampleContours('M 0,0 L 1,0 M 5,5 L 6,5',
          step: 1, minDistSq: 1e-6, map: (p) => p);
      expect(two.length, 2);
      expect(sampleContours('not a path',
          step: 1, minDistSq: 1e-6, map: (p) => p), isEmpty);
    });
  });

  test('computeFillLines hatches a square boustrophedon-style', () {
    final square = Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10));
    final lines = computeFillLines(square, FillDirection.horizontal, 1);
    expect(lines.length, 10);
    expect(lines.first.$1.dy, 0.5);
    expect(lines.first.$1.dx, lessThan(lines.first.$2.dx));
    expect(lines[1].$1.dx, greaterThan(lines[1].$2.dx));
  });
}
