import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import '../../models/svg_document.dart';
import '../../models/svg_node.dart';
import '../../models/layer_settings.dart';
import '../../services/svg_tree_parser.dart';
import '../../services/grbl_service.dart';
import '../../services/grbl_mock_service.dart';
import '../../services/grbl_serial_service.dart';
import '../../services/gcode_generator.dart';
import '../../services/toolpath.dart';
import '../../models/machine_settings.dart';
import '../../services/settings_service.dart';
import '../../widgets/connect_dialog.dart';
import '../../widgets/machine_settings_dialog.dart';
import '../../widgets/main_app_bar.dart';
import '../../widgets/gcode_dialog.dart';
import '../../widgets/svg_preview_widget.dart';
import '../../widgets/left_panel.dart';
import '../../widgets/right_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    final mock = GrblMockService();
    _grbl = mock;
    mock.connect();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final s = await SettingsService.load();
    if (!mounted) return;
    setState(() => _machineSettings = s);
    _grbl.machineSettings = s;
  }

  SvgDocument? _document;
  String _filename = '';
  SvgNode? _selectedNode;
  late GrblService _grbl;
  final List<RecentFile> _recentFiles = [];
  ToolpathData? _toolpath;
  MachineSettings _machineSettings = const MachineSettings();

  @override
  void dispose() {
    _grbl.dispose();
    super.dispose();
  }

  // ── Connection ───────────────────────────────────────────────────

  Future<void> _openMachineSettings() async {
    final result =
        await showMachineSettingsDialog(context, _machineSettings);
    if (result != null) {
      setState(() => _machineSettings = result);
      _grbl.machineSettings = result;
      SettingsService.save(result);
    }
  }

  Future<void> _openConnectDialog() async {
    // Serial connection: clicking the button toggles disconnect.
    if (_grbl is GrblSerialService && _grbl.connected) {
      _grbl.disconnect();
      return;
    }

    final result = await showConnectDialog(
      context,
      initialBaud: _machineSettings.defaultBaudRate,
    );
    if (result == null || !mounted) return;

    if (result.mock) {
      if (_grbl is GrblMockService) return; // already on mock
      final old = _grbl;
      final mock = GrblMockService()..connect();
      mock.machineSettings = _machineSettings;
      setState(() => _grbl = mock);
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    } else {
      final serial = GrblSerialService();
      final ok = await serial.connectSerial(result.port!, result.baud);
      if (!mounted) return;
      if (ok) {
        final old = _grbl;
        serial.machineSettings = _machineSettings;
        setState(() => _grbl = serial);
        WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      } else {
        serial.dispose();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot connect to ${result.port}')),
        );
      }
    }
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
    final doc = SvgTreeParser.parse(content);
    setState(() {
      _document = doc;
      _filename = filename;
      _selectedNode = null;
      _toolpath = computeToolpath(doc);
    });
  }

  // ── G-code export ────────────────────────────────────────────────

  void _exportGcode() {
    if (_document == null) return;
    final gcode = GcodeGenerator.generate(_document!, _filename, _machineSettings);
    showGcodeDialog(context, gcode, _filename);
  }

  // ── Node selection ───────────────────────────────────────────────

  void _toggleEnabled(SvgNode node) {
    setState(() {
      node.enabled = !node.enabled;
      if (_document != null) _toolpath = computeToolpath(_document!);
    });
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
    setState(() {
      node.settings = settings;
      if (_document != null) _toolpath = computeToolpath(_document!);
    });
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
        _grbl.jog(0, step, 0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _grbl.jog(0, -step, 0);
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
            onExportGcode: _document != null ? _exportGcode : null,
            isConnected: _grbl.connected,
            isSerialConnected: _grbl is GrblSerialService && _grbl.connected,
            onToggleConnect: () => _openConnectDialog(),
            onHomeAll: _grbl.homeAll,
            onSetOrigin: _grbl.setOrigin,
            onMachineSettings: _openMachineSettings,
          ),
          body: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 290,
                      child: LeftPanel(
                        document: _document,
                        selectedNode: _selectedNode,
                        machineSettings: _machineSettings,
                        onToggleEnabled: _toggleEnabled,
                        onSelect: _selectNode,
                        onSettingsChanged: _onSettingsChanged,
                      ),
                    ),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(
                      child: SvgPreviewWidget(
                        document: _document,
                        machinePos: _grbl.connected
                            ? Offset(_grbl.x, _grbl.y)
                            : null,
                        toolpath: _toolpath,
                        onJogTo: _grbl.connected
                            ? (mx, my) {
                                _grbl.jog(
                                    mx - _grbl.x, my - _grbl.y, 0);
                              }
                            : null,
                      ),
                    ),
                    const VerticalDivider(width: 1, thickness: 1),
                    SizedBox(
                      width: 290,
                      child: RightPanel(
                        document: _document,
                        service: _grbl,
                        onExportGcode:
                            _document != null ? _exportGcode : null,
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
