import 'package:flutter/material.dart';

typedef RecentFile = ({String path, String name});

class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onOpenFile;
  final List<RecentFile> recentFiles;
  final void Function(String path, String name) onOpenRecent;
  final bool isConnected;
  final VoidCallback onToggleConnect;
  final VoidCallback onHomeAll;
  final VoidCallback onSetOrigin;

  const MainAppBar({
    super.key,
    required this.onOpenFile,
    required this.recentFiles,
    required this.onOpenRecent,
    required this.isConnected,
    required this.onToggleConnect,
    required this.onHomeAll,
    required this.onSetOrigin,
  });

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
          // ── File ──────────────────────────────────────────────────
          SubmenuButton(
            style: _menuButtonStyle(),
            child: const Text('File'),
            menuChildren: [
              MenuItemButton(
                onPressed: onOpenFile,
                leadingIcon: const Icon(Icons.folder_open, size: 16),
                child: const Text('Open SVG file…'),
              ),
              if (recentFiles.isNotEmpty) ...[
                const Divider(height: 1),
                SubmenuButton(
                  leadingIcon: const Icon(Icons.history, size: 16),
                  child: const Text('Recent files'),
                  menuChildren: recentFiles
                      .map((f) => MenuItemButton(
                            onPressed: () => onOpenRecent(f.path, f.name),
                            child: Text(
                              f.name,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),

          // ── Machine ───────────────────────────────────────────────
          SubmenuButton(
            style: _menuButtonStyle(),
            child: const Text('Machine'),
            menuChildren: [
              MenuItemButton(
                onPressed: onToggleConnect,
                leadingIcon: Icon(
                  isConnected ? Icons.usb_off : Icons.usb,
                  size: 16,
                ),
                child: Text(isConnected ? 'Disconnect' : 'Connect (mock)'),
              ),
              const Divider(height: 1),
              MenuItemButton(
                onPressed: isConnected ? onHomeAll : null,
                leadingIcon: const Icon(Icons.home, size: 16),
                child: const Text('Home All'),
              ),
              MenuItemButton(
                onPressed: isConnected ? onSetOrigin : null,
                leadingIcon: const Icon(Icons.gps_fixed, size: 16),
                child: const Text('Set Origin'),
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
