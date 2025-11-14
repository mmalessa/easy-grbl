import 'package:flutter/material.dart';
import '../../services/svg_path_parser.dart';
import '../../services/svg_path_model.dart';
import '../../widgets/svg_paths_painter.dart';

class SvgViewerScreen extends StatefulWidget {
  final String? svgContent;

  const SvgViewerScreen({super.key, this.svgContent});

  @override
  State<SvgViewerScreen> createState() => _SvgViewerScreenState();
}

class _SvgViewerScreenState extends State<SvgViewerScreen> {
  late List<SvgPathModel> paths;
  late Rect viewBox;

  @override
  void initState() {
    super.initState();

    final svgContent = widget.svgContent ??
        '<svg viewBox="0 0 100 100"><path id="default" d="M 10 10 L 90 10 L 90 90 L 10 90 Z"/></svg>';

    paths = SvgPathParser.extractPaths(svgContent);
    viewBox = SvgPathParser.extractViewBox(svgContent);
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
              color: Colors.white,
              child: CustomPaint(
                painter: SvgPathsPainter(
                  paths: paths,
                  viewBox: viewBox,
                ),
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
                  title: Text('Path ${index + 1}: ${path.id}'), // id zamiast d
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
