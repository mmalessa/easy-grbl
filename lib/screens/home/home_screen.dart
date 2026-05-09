import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import '../../models/svg_document.dart';
import '../../models/svg_node.dart';
import '../../models/layer_settings.dart';
import '../../services/svg_tree_parser.dart';
import '../../services/grbl_mock_service.dart';
import '../../widgets/main_app_bar.dart';
import '../../widgets/svg_preview_widget.dart';
import '../../widgets/right_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  SvgDocument? _document;
  String _filename = '';
  SvgNode? _selectedNode;
  final _grbl = GrblMockService();
  final List<RecentFile> _recentFiles = [];

  @override
  void dispose() {
    _grbl.dispose();
    super.dispose();
  }

  // ── File operations ──────────────────────────────────────────────

  Future<void> _openFile() async {
    const typeGroup = XTypeGroup(label: 'SVG', extensions: ['svg']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;
    final content = await file.readAsString();
    _onFileLoaded(content, file.name);
    _addRecent(file.path, file.name);
  }

  Future<void> _openRecentFile(String path, String name) async {
    try {
      final content = await File(path).readAsString();
      _onFileLoaded(content, name);
      _addRecent(path, name);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot open $name — file not found.')),
        );
        setState(() => _recentFiles.removeWhere((f) => f.path == path));
      }
    }
  }

  void _addRecent(String path, String name) {
    setState(() {
      _recentFiles.removeWhere((f) => f.path == path);
      _recentFiles.insert(0, (path: path, name: name));
      if (_recentFiles.length > 8) _recentFiles.removeLast();
    });
  }

  void _onFileLoaded(String content, String filename) {
    setState(() {
      _document = SvgTreeParser.parse(content);
      _filename = filename;
      _selectedNode = null;
    });
  }

  // ── Node selection ───────────────────────────────────────────────

  void _toggleEnabled(SvgNode node) {
    setState(() => node.enabled = !node.enabled);
  }

  void _selectNode(SvgNode node) {
    setState(() {
      _deselectAll(_document!.roots);
      if (_selectedNode?.id == node.id) {
        _selectedNode = null;
      } else {
        node.selected = true;
        _selectedNode = node;
      }
    });
  }

  void _onSettingsChanged(SvgNode node, LayerSettings settings) {
    setState(() => node.settings = settings);
  }

  void _deselectAll(List<SvgNode> nodes) {
    for (final n in nodes) {
      n.selected = false;
      _deselectAll(n.children);
    }
  }

  // ── Keyboard jog ─────────────────────────────────────────────────

  KeyEventResult _handleKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final step = _grbl.stepMm;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        _grbl.jog(-step, 0, 0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _grbl.jog(step, 0, 0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _grbl.jog(0, -step, 0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _grbl.jog(0, step, 0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.pageUp:
        _grbl.jog(0, 0, step);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.pageDown:
        _grbl.jog(0, 0, -step);
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _grbl,
      builder: (context, _) => Focus(
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Scaffold(
          appBar: MainAppBar(
            onOpenFile: _openFile,
            recentFiles: _recentFiles,
            onOpenRecent: _openRecentFile,
            isConnected: _grbl.connected,
            onToggleConnect: () => _grbl.connected
                ? _grbl.disconnect()
                : _grbl.connect(),
            onHomeAll: _grbl.homeAll,
            onSetOrigin: _grbl.setOrigin,
          ),
          body: Column(
            children: [
              _StatusBar(filename: _filename, grbl: _grbl),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: SvgPreviewWidget(
                        document: _document,
                        machinePos: Offset(_grbl.x, _grbl.y),
                      ),
                    ),
                    const VerticalDivider(width: 1, thickness: 1),
                    SizedBox(
                      width: 290,
                      child: RightPanel(
                        document: _document,
                        selectedNode: _selectedNode,
                        service: _grbl,
                        onToggleEnabled: _toggleEnabled,
                        onSelect: _selectNode,
                        onSettingsChanged: _onSettingsChanged,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _StatusBar extends StatelessWidget {
  final String filename;
  final GrblMockService grbl;
  const _StatusBar({required this.filename, required this.grbl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      color: Colors.grey[850] ?? const Color(0xFF212121),
      child: Row(
        children: [
          Text(
            filename.isEmpty ? 'No file loaded' : filename,
            style: TextStyle(
              fontSize: 11,
              color: filename.isEmpty ? Colors.grey[600] : Colors.grey[400],
            ),
          ),
          const Spacer(),
          if (grbl.connected) ...[
            _PosLabel('X', grbl.x),
            const SizedBox(width: 10),
            _PosLabel('Y', grbl.y),
            const SizedBox(width: 10),
            _PosLabel('Z', grbl.z),
            const SizedBox(width: 12),
            _StatusChip(grbl: grbl),
          ] else
            _OfflineChip(),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final GrblMockService grbl;
  const _StatusChip({required this.grbl});

  @override
  Widget build(BuildContext context) {
    final rgb = grbl.status.rgb;
    final statusColor = Color.fromRGBO(rgb.r, rgb.g, rgb.b, 1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.2),
        border: Border.all(color: statusColor, width: 0.8),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        grbl.status.label,
        style: TextStyle(
          color: statusColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _OfflineChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.15),
        border: Border.all(color: Colors.grey, width: 0.8),
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Text(
        'OFFLINE',
        style: TextStyle(
          color: Colors.grey,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _PosLabel extends StatelessWidget {
  final String axis;
  final double value;
  const _PosLabel(this.axis, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$axis:',
          style: const TextStyle(
              fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 3),
        Text(
          value.toStringAsFixed(3),
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white70,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
