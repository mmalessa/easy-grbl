import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:easy_grbl/geometry/contour_sampler.dart';
import 'package:easy_grbl/geometry/fill_lines.dart';
import 'package:easy_grbl/geometry/fill_toolpath.dart';
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

  group('computeFillToolpath keeps the burn inside the filled shape', () {
    // Distance from p to the nearest point of a circle of radius r at c.
    double edgeDist(Offset p, Offset c, double r) => ((p - c).distance - r).abs();

    test('outline of a circle runs half a spot inside its edge', () {
      const c = Offset(20, 20);
      final circle = Path()..addOval(Rect.fromCircle(center: c, radius: 10));
      final tp = computeFillToolpath(circle,
          direction: FillDirection.horizontal, linesPerMm: 5,
          spotDiameter: 0.4, outline: true);
      expect(tp.outline, hasLength(1));
      for (final p in tp.outline.single) {
        expect((p - c).distance, closeTo(9.8, 0.02));
      }
      // Hatch ends on the outline, never closer to the edge.
      for (final l in tp.lines) {
        for (final p in [l.$1, l.$2]) {
          expect((p - c).distance, lessThanOrEqualTo(9.8 + 0.02));
        }
      }
    });

    test('hole outline runs half a spot outside the hole', () {
      const c = Offset(20, 20);
      final ring = Path()
        ..fillType = PathFillType.evenOdd
        ..addOval(Rect.fromCircle(center: c, radius: 10))
        ..addOval(Rect.fromCircle(center: c, radius: 4));
      final tp = computeFillToolpath(ring,
          direction: FillDirection.vertical, linesPerMm: 5,
          spotDiameter: 0.4, outline: true);
      expect(tp.outline, hasLength(2));
      final radii = tp.outline
          .map((pts) => (pts.first - c).distance)
          .toList()
        ..sort();
      expect(radii[0], closeTo(4.2, 0.02));
      expect(radii[1], closeTo(9.8, 0.02));
      for (final l in tp.lines) {
        for (final p in [l.$1, l.$2]) {
          expect((p - c).distance, inInclusiveRange(4.2 - 0.02, 9.8 + 0.02));
          expect(edgeDist(p, c, 10), greaterThanOrEqualTo(0.18));
        }
      }
    });

    test('hatch stays inside even without an outline', () {
      final square = Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10));
      final tp = computeFillToolpath(square,
          direction: FillDirection.horizontal, linesPerMm: 1,
          spotDiameter: 0.4, outline: false);
      expect(tp.outline, isEmpty);
      for (final l in tp.lines) {
        expect([l.$1.dx, l.$2.dx].reduce((a, b) => a < b ? a : b),
            closeTo(0.2, 0.01));
        expect([l.$1.dx, l.$2.dx].reduce((a, b) => a > b ? a : b),
            closeTo(9.8, 0.01));
      }
    });

    test('shape narrower than the spot falls back to its edge', () {
      final sliver = Path()..addRect(const Rect.fromLTWH(0, 0, 10, 0.3));
      final tp = computeFillToolpath(sliver,
          direction: FillDirection.horizontal, linesPerMm: 10,
          spotDiameter: 0.4, outline: true);
      expect(tp.outline, hasLength(1));
      final bounds = tp.outline.single
          .map((p) => Rect.fromCenter(center: p, width: 0, height: 0))
          .reduce((a, b) => a.expandToInclude(b));
      expect(bounds.top, closeTo(0, 1e-3));
      expect(bounds.bottom, closeTo(0.3, 1e-3));
      expect(bounds.width, closeTo(10, 1e-3));
    });
  });
}
