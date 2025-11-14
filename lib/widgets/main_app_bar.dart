import 'package:flutter/material.dart';
import '../screens/svg_viewer/svg_viewer_screen.dart';
import 'package:file_selector/file_selector.dart';

class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MainAppBar({super.key});

  void _openTestSvg(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SvgViewerScreen()),
    );
  }

  Future<void> _selectSvgFile(BuildContext context) async {
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
      title: MenuBar(
        style: MenuStyle(
          backgroundColor: MaterialStateProperty.all(Colors.transparent),
          elevation: MaterialStateProperty.all(0),
        ),
        children: [
          SubmenuButton(
            menuChildren: [
              MenuItemButton(
                onPressed: () => _openTestSvg(context),
                child: const Text('Open test SVG'),
              ),
              MenuItemButton(
                onPressed: () => _selectSvgFile(context),
                child: const Text('Select SVG file'),
              ),
            ],
            child: const Text('File'),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
