import 'package:flutter/material.dart';
import '../svg_viewer/svg_viewer_screen.dart';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import '../svg_viewer/svg_viewer_screen.dart';


class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CNC Panel'),
      ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SvgViewerScreen()),
                  );
                },
                child: const Text('Open test SVG'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final XTypeGroup typeGroup = XTypeGroup(
                    label: 'SVG',
                    extensions: ['svg'],
                  );

                  final XFile? file =
                  await openFile(acceptedTypeGroups: [typeGroup]);

                  if (file == null) return;

                  final content = await file.readAsString();

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SvgViewerScreen(svgContent: content),
                    ),
                  );
                },
                child: const Text('Select SVG file'),
              ),
            ],
          ),
        ),
    );
  }
}
