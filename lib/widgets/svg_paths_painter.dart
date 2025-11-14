import 'package:flutter/material.dart';
import '../services/svg_path_model.dart';
import 'package:path_drawing/path_drawing.dart'; // potrzebne do parsowania d=""

class SvgPathsPainter extends CustomPainter {
  final List<SvgPathModel> paths;

  SvgPathsPainter(this.paths);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.black;

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
  bool shouldRepaint(covariant SvgPathsPainter oldDelegate) => true;
}
