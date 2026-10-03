import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:easy_grbl/geometry/affine.dart';
import 'package:easy_grbl/geometry/fill_toolpath.dart';
import 'package:easy_grbl/geometry/negative_fill.dart';
import 'package:easy_grbl/geometry/svg_node_walker.dart';
import 'package:easy_grbl/models/layer_settings.dart';
import 'package:easy_grbl/models/operation_type.dart';
import 'package:easy_grbl/models/svg_node.dart';
import 'package:easy_grbl/models/svg_node_type.dart';
import 'package:easy_grbl/services/job_step_counter.dart';

const _spot = 0.4;
const _r = _spot / 2;
const _tol = 0.005; // sampling / integer-rounding slack, mm
const _area = Rect.fromLTWH(0, 0, 40, 30);

FillToolpath _negative(List<Path> obstacles,
        {double linesPerMm = 5, bool outline = true}) =>
    computeNegativeFillToolpath(_area, obstacles,
        direction: FillDirection.horizontal,
        linesPerMm: linesPerMm,
        spotDiameter: _spot,
        outline: outline);

/// Every point the spot centre passes through: outline vertices plus hatch
/// lines sampled every 0.05 mm (a straight segment can dip between ends).
List<Offset> _burnPoints(FillToolpath tp) => [
      for (final c in tp.outline) ...c,
      for (final (a, b) in tp.lines)
        for (var t = 0.0; t <= 1.0; t += 0.05 / math.max((b - a).distance, 0.05))
          Offset.lerp(a, b, t)!,
    ];

double _distToRect(Offset p, Rect r) {
  final dx = math.max(math.max(r.left - p.dx, 0.0), p.dx - r.right);
  final dy = math.max(math.max(r.top - p.dy, 0.0), p.dy - r.bottom);
  if (dx == 0 && dy == 0) return 0; // inside
  return math.sqrt(dx * dx + dy * dy);
}

double _distToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / ab.distanceSquared)
      .clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

void _expectInsideArea(Iterable<Offset> pts) {
  for (final p in pts) {
    expect(p.dx, greaterThanOrEqualTo(_area.left + _r - _tol));
    expect(p.dx, lessThanOrEqualTo(_area.right - _r + _tol));
    expect(p.dy, greaterThanOrEqualTo(_area.top + _r - _tol));
    expect(p.dy, lessThanOrEqualTo(_area.bottom - _r + _tol));
  }
}

void main() {
  group('computeNegativeFillToolpath never lets the spot enter an object', () {
    test('square obstacle: spot stays half a spot away, inside the area', () {
      const obj = Rect.fromLTWH(10, 10, 10, 8);
      final tp = _negative([Path()..addRect(obj)]);
      expect(tp.lines, isNotEmpty);
      // Area frame + the ring around the object.
      expect(tp.outline, hasLength(2));
      final pts = _burnPoints(tp);
      for (final p in pts) {
        expect(_distToRect(p, obj), greaterThanOrEqualTo(_r - _tol));
      }
      _expectInsideArea(pts);
      // The outline hugs the object at exactly half a spot.
      final ring = tp.outline.firstWhere(
          (c) => c.every((p) => _distToRect(p, obj) < 1));
      for (final p in ring) {
        expect(_distToRect(p, obj), closeTo(_r, _tol));
      }
    });

    test('circle obstacle', () {
      const c = Offset(25, 15);
      final tp = _negative(
          [Path()..addOval(Rect.fromCircle(center: c, radius: 5))]);
      for (final p in _burnPoints(tp)) {
        expect((p - c).distance, greaterThanOrEqualTo(5 + _r - _tol));
      }
    });

    test('open line obstacle is kept at half a spot', () {
      const a = Offset(5, 5), b = Offset(30, 20);
      final tp = _negative([Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)]);
      expect(tp.lines, isNotEmpty);
      for (final p in _burnPoints(tp)) {
        expect(_distToSegment(p, a, b), greaterThanOrEqualTo(_r - _tol));
      }
    });

    test('a hole in an object is outside it, so it gets filled', () {
      const c = Offset(20, 15);
      final ring = Path()
        ..fillType = PathFillType.evenOdd
        ..addOval(Rect.fromCircle(center: c, radius: 10))
        ..addOval(Rect.fromCircle(center: c, radius: 4));
      final tp = _negative([ring]);
      final inHole =
          _burnPoints(tp).where((p) => (p - c).distance < 4).toList();
      expect(inHole, isNotEmpty);
      for (final p in _burnPoints(tp)) {
        final d = (p - c).distance;
        expect(d < 4 - _r + _tol || d > 10 + _r - _tol, isTrue,
            reason: 'point $p at distance $d enters the ring');
      }
    });

    test('a gap narrower than the spot stays unburned', () {
      const left = Rect.fromLTWH(10, 10, 5, 10);
      const right = Rect.fromLTWH(15.3, 10, 5, 10); // 0.3 mm gap < spot
      final tp = _negative([Path()..addRect(left), Path()..addRect(right)]);
      for (final p in _burnPoints(tp)) {
        expect(_distToRect(p, left), greaterThanOrEqualTo(_r - _tol));
        expect(_distToRect(p, right), greaterThanOrEqualTo(_r - _tol));
      }
    });

    test('without obstacles the whole area (minus half a spot) is filled', () {
      final tp = _negative(const [], outline: false);
      expect(tp.outline, isEmpty);
      final xs = [for (final (a, b) in tp.lines) ...[a.dx, b.dx]];
      expect(xs.reduce(math.min), closeTo(_r, _tol));
      expect(xs.reduce(math.max), closeTo(_area.width - _r, _tol));
    });
  });

  group('negative fill groups', () {
    SvgNode path(String id, String d, [LayerSettings? s]) => SvgNode(
        id: id, label: id, type: SvgNodeType.path, pathData: d, settings: s);

    SvgNode group({required bool negative}) => SvgNode(
          id: 'g',
          label: 'g',
          type: SvgNodeType.group,
          transform: 'translate(5,0)',
          settings: LayerSettings(
              operationType: OperationType.fill, fillNegative: negative),
          children: [
            path('a', 'M 0,0 L 2,0 L 2,2 Z'),
            path('b', 'M 10,10 L 12,10 L 12,12 Z',
                LayerSettings(operationType: OperationType.cut)),
            path('hidden', 'M 20,20 L 22,20 L 22,22 Z')..enabled = false,
          ],
        );

    test('obstacles: every visible path, own operation or not, transformed',
        () {
      final g = group(negative: true);
      final obstacles =
          negativeFillObstacles(g, SvgAffine.fromSvgString(g.transform));
      expect(obstacles, hasLength(2));
      expect(obstacles.first.getBounds(), const Rect.fromLTRB(5, 0, 7, 2));
    });

    test('children inheriting the negative fill are not filled on their own',
        () {
      final g = group(negative: true);
      final a = g.children[0], b = g.children[1];
      expect(isNegativeFillGroup(g), isTrue);
      expect(isCoveredByNegativeFill(a, OperationType.fill, g.settings), isTrue);
      expect(isCoveredByNegativeFill(b, OperationType.cut, b.settings), isFalse);
      // Group fill (1) + the child's own Cut (1); the covered child adds none.
      expect(countJobSteps([g]), (paths: 2, passes: 2));
      expect(countJobSteps([group(negative: false)]), (paths: 2, passes: 2));
    });

    test('negative is ignored on a plain path', () {
      final p = path('p', 'M 0,0 L 2,0 L 2,2 Z',
          LayerSettings(operationType: OperationType.fill, fillNegative: true));
      expect(isNegativeFillGroup(p), isFalse);
      expect(isCoveredByNegativeFill(p, OperationType.fill, p.settings), isFalse);
    });
  });
}
