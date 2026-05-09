import 'package:flutter/material.dart';
import '../models/svg_document.dart';
import 'svg_document_painter.dart';

class SvgPreviewWidget extends StatelessWidget {
  final SvgDocument? document;

  const SvgPreviewWidget({super.key, this.document});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2C2C2C),
      child: document == null ? _empty() : _canvas(),
    );
  }

  Widget _canvas() {
    return LayoutBuilder(
      builder: (context, constraints) => InteractiveViewer(
        boundaryMargin: const EdgeInsets.all(double.infinity),
        minScale: 0.05,
        maxScale: 100,
        child: SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: CustomPaint(
            painter: SvgDocumentPainter(document: document!),
          ),
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open_outlined, size: 56, color: Colors.grey[600]),
          const SizedBox(height: 12),
          Text(
            'Open an SVG file to get started',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'File → Open SVG file',
            style: TextStyle(color: Colors.grey[700], fontSize: 11),
          ),
        ],
      ),
    );
  }
}
