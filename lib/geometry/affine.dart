import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// 2-D affine matrix.
/// x' = a·x + c·y + e
/// y' = b·x + d·y + f
class SvgAffine {
  final double a, b, c, d, e, f;

  const SvgAffine(this.a, this.b, this.c, this.d, this.e, this.f);

  static const identity = SvgAffine(1, 0, 0, 1, 0, 0);

  Offset apply(Offset p) =>
      Offset(a * p.dx + c * p.dy + e, b * p.dx + d * p.dy + f);

  /// Returns a matrix that first applies [other], then [this].
  SvgAffine multiply(SvgAffine o) => SvgAffine(
        a * o.a + c * o.b,
        b * o.a + d * o.b,
        a * o.c + c * o.d,
        b * o.c + d * o.d,
        a * o.e + c * o.f + e,
        b * o.e + d * o.f + f,
      );

  /// Column-major Float64List for Flutter's Path.transform().
  Float64List toFloat64() => Float64List.fromList([
        a, b, 0, 0,
        c, d, 0, 0,
        0, 0, 1, 0,
        e, f, 0, 1,
      ]);

  static SvgAffine fromSvgString(String? s) {
    if (s == null || s.isEmpty) return identity;
    var result = identity;
    final re = RegExp(r'(\w+)\(([^)]+)\)');
    for (final m in re.allMatches(s)) {
      final fn = m.group(1)!;
      final args = m
          .group(2)!
          .trim()
          .split(RegExp(r'[\s,]+'))
          .map(double.tryParse)
          .whereType<double>()
          .toList();
      result = result.multiply(_fromFn(fn, args));
    }
    return result;
  }

  static SvgAffine _fromFn(String fn, List<double> args) {
    switch (fn) {
      case 'translate':
        return SvgAffine(1, 0, 0, 1,
            args.isNotEmpty ? args[0] : 0, args.length > 1 ? args[1] : 0);
      case 'scale':
        final sx = args.isNotEmpty ? args[0] : 1.0;
        final sy = args.length > 1 ? args[1] : sx;
        return SvgAffine(sx, 0, 0, sy, 0, 0);
      case 'rotate':
        if (args.isEmpty) return identity;
        final ang = args[0] * math.pi / 180;
        final ca = math.cos(ang), sa = math.sin(ang);
        if (args.length >= 3) {
          final cx = args[1], cy = args[2];
          return SvgAffine(ca, sa, -sa, ca,
              cx - cx * ca + cy * sa, cy - cx * sa - cy * ca);
        }
        return SvgAffine(ca, sa, -sa, ca, 0, 0);
      case 'matrix':
        if (args.length >= 6) {
          return SvgAffine(
              args[0], args[1], args[2], args[3], args[4], args[5]);
        }
        return identity;
      default:
        return identity;
    }
  }
}
