import 'package:flutter/material.dart';
import '../services/svg_path_model.dart';
import 'package:path_drawing/path_drawing.dart'; // potrzebne do parsowania d=""

class SvgPathsPainter extends CustomPainter {
  final List<SvgPathModel> paths;
  final Rect viewBox; // np. 0,0,16,16 z SVG

  SvgPathsPainter({required this.paths, required this.viewBox});

  @override
  void paint(Canvas canvas, Size size) {
    // // Skalowanie z viewBox -> widget size
    final scaleX = size.width / viewBox.width;
    final scaleY = size.height / viewBox.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    canvas.scale(scale);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.2
      ..color = Colors.black;

    canvas.translate(-viewBox.left, -viewBox.top);

    for (var pathModel in paths) {
      try {
        final path = parseSvgPathData(pathModel.d);
        paint.color = pathModel.selected ? Colors.green : Colors.black;
        canvas.drawPath(path, paint);
      } catch (e) {
        debugPrint('Could not parse path: ${pathModel.d} ${e.toString()}');
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

