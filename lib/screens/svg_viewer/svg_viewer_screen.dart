import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/svg_path_parser.dart';
import '../../services/svg_path_model.dart';
import 'dart:ui' as ui;
import '../../widgets/svg_paths_painter.dart';



class SvgViewerScreen extends StatefulWidget {
  final String? svgContent;

  const SvgViewerScreen({super.key, this.svgContent});

  @override
  State<SvgViewerScreen> createState() => _SvgViewerScreenState();
}

class _SvgViewerScreenState extends State<SvgViewerScreen> {
  late List<SvgPathModel> paths;

  @override
  void initState() {
    super.initState();
    paths = (widget.svgContent != null
        ? SvgPathParser.extractPaths(widget.svgContent!)
        : SvgPathParser.extractPaths(
        '<svg><path d="M 10 10 L 190 10 L 190 190 L 10 190 Z"/></svg>'))
        .map((d) => SvgPathModel(d: d))
        .toList();
  }

  void toggleSelection(int index) {
    setState(() {
      paths[index].selected = !paths[index].selected;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SVG Viewer')),
      body: Column(
        children: [
          // Podgląd SVG
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white, // tło canvas
              child: CustomPaint(
                painter: SvgPathsPainter(paths),
                child: Container(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Lista ścieżek z możliwością zaznaczenia
          Expanded(
            flex: 1,
            child: ListView.builder(
              itemCount: paths.length,
              itemBuilder: (context, index) {
                final path = paths[index];
                return ListTile(
                  title: Text('Path ${index + 1}: ${path.d}'),
                  tileColor: path.selected ? Colors.green[200] : null,
                  onTap: () => toggleSelection(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
