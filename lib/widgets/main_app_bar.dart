import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';

class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  final void Function(String content, String filename) onFileLoaded;

  const MainAppBar({super.key, required this.onFileLoaded});

  Future<void> _openSvgFile() async {
    const typeGroup = XTypeGroup(label: 'SVG', extensions: ['svg']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;
    final content = await file.readAsString();
    onFileLoaded(content, file.name);
  }

  Future<void> _openAsset(String filename) async {
    final content = await rootBundle.loadString('assets/$filename');
    onFileLoaded(content, filename);
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.grey[900],
      foregroundColor: Colors.white,
      titleSpacing: 0,
      title: MenuBar(
        style: MenuStyle(
          backgroundColor: WidgetStateProperty.all(Colors.transparent),
          elevation: WidgetStateProperty.all(0),
        ),
        children: [
          SubmenuButton(
            style: _menuButtonStyle(),
            child: const Text('File'),
            menuChildren: [
              MenuItemButton(
                onPressed: _openSvgFile,
                leadingIcon: const Icon(Icons.folder_open, size: 16),
                child: const Text('Open SVG file...'),
              ),
              const Divider(height: 1),
              MenuItemButton(
                onPressed: () => _openAsset('test.svg'),
                child: const Text('Open test.svg'),
              ),
              MenuItemButton(
                onPressed: () => _openAsset('test_2.svg'),
                child: const Text('Open test_2.svg'),
              ),
            ],
          ),
          SubmenuButton(
            style: _menuButtonStyle(),
            child: const Text('Machine'),
            menuChildren: [
              MenuItemButton(
                onPressed: () {},
                leadingIcon: const Icon(Icons.usb, size: 16),
                child: const Text('Connect (mock)'),
              ),
              MenuItemButton(
                onPressed: () {},
                leadingIcon: const Icon(Icons.home, size: 16),
                child: const Text('Home All'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  ButtonStyle _menuButtonStyle() => ButtonStyle(
        foregroundColor: WidgetStateProperty.all(Colors.white70),
        overlayColor: WidgetStateProperty.all(Colors.white12),
      );

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
