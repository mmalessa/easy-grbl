import 'package:flutter/material.dart';

typedef RecentFile = ({String path, String name});

class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onOpenFile;
  final List<RecentFile> recentFiles;
  final void Function(String path, String name) onOpenRecent;
  final VoidCallback? onExportGcode;
  final VoidCallback onFocusTest;
  final VoidCallback onKerfTest;
  final VoidCallback onSpotTest;
  final bool isConnected;
  final bool isSerialConnected;
  final VoidCallback onToggleConnect;
  final VoidCallback onMachineSettings;
  final VoidCallback onAbout;

  const MainAppBar({
    super.key,
    required this.onOpenFile,
    required this.recentFiles,
    required this.onOpenRecent,
    this.onExportGcode,
    required this.onFocusTest,
    required this.onKerfTest,
    required this.onSpotTest,
    required this.isConnected,
    required this.isSerialConnected,
    required this.onToggleConnect,
    required this.onMachineSettings,
    required this.onAbout,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppBar(
      toolbarHeight: 38,
      backgroundColor: cs.surfaceContainerHigh,
      foregroundColor: cs.onSurface,
      titleSpacing: 0,
      title: MenuBar(
        style: MenuStyle(
          backgroundColor: WidgetStateProperty.all(Colors.transparent),
          elevation: WidgetStateProperty.all(0),
        ),
        children: [
          SubmenuButton(
            style: _menuButtonStyle(cs),
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
                  menuChildren: recentFiles
                      .map((f) => MenuItemButton(
                            onPressed: () => onOpenRecent(f.path, f.name),
                            child: Text(
                              f.name,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ))
                      .toList(),
                  child: const Text('Recent files'),
                ),
              ],
              if (onExportGcode != null) ...[
                const Divider(height: 1),
                MenuItemButton(
                  onPressed: onExportGcode,
                  leadingIcon: const Icon(Icons.code, size: 16),
                  child: const Text('Export G-code…'),
                ),
              ],
              const Divider(height: 1),
              SubmenuButton(
                leadingIcon: const Icon(Icons.auto_fix_high_outlined, size: 16),
                menuChildren: [
                  MenuItemButton(
                    onPressed: onFocusTest,
                    leadingIcon: const Icon(Icons.my_location, size: 16),
                    child: const Text('Focus Test'),
                  ),
                  MenuItemButton(
                    onPressed: onKerfTest,
                    leadingIcon: const Icon(Icons.straighten, size: 16),
                    child: const Text('Kerf Test'),
                  ),
                  MenuItemButton(
                    onPressed: onSpotTest,
                    leadingIcon: const Icon(Icons.grid_on, size: 16),
                    child: const Text('Spot Size Test'),
                  ),
                ],
                child: const Text('Templates'),
              ),
            ],
            child: const Text('File'),
          ),

          SubmenuButton(
            style: _menuButtonStyle(cs),
            menuChildren: [
              MenuItemButton(
                onPressed: onToggleConnect,
                leadingIcon: Icon(
                  isSerialConnected ? Icons.usb_off : Icons.usb,
                  size: 16,
                ),
                child: Text(isSerialConnected ? 'Disconnect' : 'Connect…'),
              ),
              const Divider(height: 1),
              MenuItemButton(
                onPressed: onMachineSettings,
                leadingIcon: const Icon(Icons.settings, size: 16),
                child: const Text('Settings…'),
              ),
            ],
            child: const Text('Machine'),
          ),

          SubmenuButton(
            style: _menuButtonStyle(cs),
            menuChildren: [
              MenuItemButton(
                onPressed: onAbout,
                leadingIcon: const Icon(Icons.info_outline, size: 16),
                child: const Text('About'),
              ),
            ],
            child: const Text('Help'),
          ),
        ],
      ),
    );
  }

  ButtonStyle _menuButtonStyle(ColorScheme cs) => ButtonStyle(
        foregroundColor: WidgetStateProperty.all(cs.onSurface.withValues(alpha: 0.7)),
        overlayColor: WidgetStateProperty.all(cs.onSurface.withValues(alpha: 0.12)),
      );

  @override
  Size get preferredSize => const Size.fromHeight(38);
}
