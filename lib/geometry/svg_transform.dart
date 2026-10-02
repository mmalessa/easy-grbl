import 'package:flutter/rendering.dart';
import 'affine.dart';

void applySvgTransform(Canvas canvas, String? transform) {
  if (transform == null || transform.isEmpty) return;
  canvas.transform(SvgAffine.fromSvgString(transform).toFloat64());
}
