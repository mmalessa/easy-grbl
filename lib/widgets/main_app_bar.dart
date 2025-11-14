import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/svg_viewer/svg_viewer_screen.dart';
import 'package:file_selector/file_selector.dart';

class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MainAppBar({super.key});

  Future<void> _openTestSvg(BuildContext context, String filename) async {
    final content = await rootBundle.loadString('assets/${filename}');

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SvgViewerScreen(svgContent: content),
      ),
    );
  }

  Future<void> _openSvgFile(BuildContext context) async {
    final XTypeGroup typeGroup = XTypeGroup(
      label: 'SVG',
      extensions: ['svg'],
    );

    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

    if (file == null) return;

    final content = await file.readAsString();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SvgViewerScreen(svgContent: content),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.black12,
      title: MenuBar(
        style: MenuStyle(
          backgroundColor: WidgetStateProperty.all(Colors.transparent),
          elevation: WidgetStateProperty.all(0),
        ),
        children: [
          SubmenuButton(
            child: const Text('File'),
            menuChildren: [
              MenuItemButton(
                onPressed: () => _openSvgFile(context),
                child: const Text('Open SVG file'),
              ),
              MenuItemButton(
                onPressed: () => _openTestSvg(context, 'test.svg'),
                child: const Text('Open test.svg'),
              ),
              MenuItemButton(
                onPressed: () => _openTestSvg(context, 'test_2.svg'),
                child: const Text('Open test_2.svg'),
              ),
            ],
          ),
          SubmenuButton(
            child: const Text('Other'),
            menuChildren: [
              MenuItemButton(
                onPressed: () => {},
                child: const Text('Something'),
              ),
            ],
          )
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
