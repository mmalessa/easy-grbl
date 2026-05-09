import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/rendering.dart';

void applySvgTransform(Canvas canvas, String? transform) {
  if (transform == null || transform.isEmpty) return;
  final re = RegExp(r'(\w+)\(([^)]+)\)');
  for (final m in re.allMatches(transform)) {
    final fn = m.group(1)!;
    final args = m
        .group(2)!
        .trim()
        .split(RegExp(r'[\s,]+'))
        .map(double.tryParse)
        .whereType<double>()
        .toList();
    _apply(canvas, fn, args);
  }
}

void _apply(Canvas canvas, String fn, List<double> args) {
  switch (fn) {
    case 'translate':
      canvas.translate(
        args.isNotEmpty ? args[0] : 0,
        args.length > 1 ? args[1] : 0,
      );
    case 'scale':
      final sx = args.isNotEmpty ? args[0] : 1.0;
      canvas.scale(sx, args.length > 1 ? args[1] : sx);
    case 'rotate':
      if (args.isEmpty) return;
      final angle = args[0] * math.pi / 180;
      if (args.length >= 3) {
        canvas.translate(args[1], args[2]);
        canvas.rotate(angle);
        canvas.translate(-args[1], -args[2]);
      } else {
        canvas.rotate(angle);
      }
    case 'matrix':
      // SVG matrix(a,b,c,d,e,f) → column-major 4×4 Float64List
      if (args.length >= 6) {
        canvas.transform(Float64List.fromList([
          args[0], args[1], 0, 0,
          args[2], args[3], 0, 0,
          0,       0,       1, 0,
          args[4], args[5], 0, 1,
        ]));
      }
  }
}
