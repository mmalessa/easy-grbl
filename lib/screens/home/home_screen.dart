import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import '../../models/svg_document.dart';
import '../../models/svg_node.dart';
import '../../models/svg_node_type.dart';
import '../../models/layer_settings.dart';
import '../../models/operation_type.dart';
import '../../services/svg_tree_parser.dart';
import '../../services/grbl_service.dart';
import '../../services/grbl_mock_service.dart';
import '../../services/grbl_serial_service.dart';
import '../../services/gcode_generator.dart';
import '../../services/gcode_templates.dart';
import '../../services/toolpath.dart';
import '../../models/machine_settings.dart';
import '../../models/focus_test_config.dart';
import '../../models/kerf_test_config.dart';
import '../../models/spot_test_config.dart';
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
    _grbl = GrblMockService();
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
  String? _lastDirectory;

  // Focus Test
  bool _showFocusTest = false;
  FocusTestConfig _focusTestConfig = const FocusTestConfig();
  SvgDocument? _focusTestDocument;

  // Kerf Test
  bool _showKerfTest = false;
  KerfTestConfig _kerfTestConfig = const KerfTestConfig();
  SvgDocument? _kerfTestDocument;

  // Spot Size Test
  bool _showSpotTest = false;
  SpotTestConfig _spotTestConfig = const SpotTestConfig();
  SvgDocument? _spotTestDocument;

  @override
  void dispose() {
    _grbl.dispose();
    super.dispose();
  }

  // ── Connection ───────────────────────────────────────────────────

  Future<void> _openMachineSettings() async {
    final result =
        await showMachineSettingsDialog(context, _machineSettings, _grbl);
    if (result != null) {
      setState(() => _machineSettings = result);
      _grbl.machineSettings = result;
      SettingsService.save(result);
    }
  }

  void _onAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'EasyGRBL',
      applicationVersion: 'build 2026-05-14',
      applicationIcon: const Icon(Icons.lightbulb_outline, size: 48),
      children: [
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Text('github.com/mmalessa/easy-grbl'),
        ),
        Text(
          '(c) 2026 github.com/mmalessa',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _openConnectDialog() async {
    // If already connected (serial or mock), disconnect.
    if (_grbl.connected) {
      _grbl.disconnect();
      return;
    }

    final result = await showConnectDialog(
      context,
      initialBaud: _machineSettings.defaultBaudRate,
    );
    if (result == null || !mounted) return;

    if (result.mock) {
      if (_grbl is GrblMockService && _grbl.connected) return; // already connected
      if (_grbl is GrblMockService) {
        (_grbl as GrblMockService).connect(); // reconnect existing mock
        return;
      }
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
    final file = await openFile(
      acceptedTypeGroups: [typeGroup],
      initialDirectory: _lastDirectory,
    );
    if (file == null) return;
    _lastDirectory = File(file.path).parent.path;
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
      _toolpath = computeToolpath(doc, _machineSettings);
    });
  }

  // ── G-code export ────────────────────────────────────────────────

  void _exportGcode() {
    if (_document == null) return;
    final gcode = GcodeGenerator.generate(_document!, _filename, _machineSettings);
    showGcodeDialog(context, gcode, _filename);
  }

  // ── Templates ────────────────────────────────────────────────────

  SvgDocument _buildFocusTestDocument(FocusTestConfig cfg) {
    final nodes = <SvgNode>[];
    final half = ((cfg.lineCount - 1) / 2).floor();
    for (var i = 0; i < cfg.lineCount; i++) {
      final svgY = (cfg.lineCount - 1) - i;
      final z = (i - half) * cfg.zStep;
      nodes.add(SvgNode(
        id: 'line_$i',
        label: 'Z=${z.toStringAsFixed(1)}',
        type: SvgNodeType.path,
        pathData: 'M 0,$svgY L ${cfg.widthMm},$svgY',
        settings: LayerSettings(
          operationType: z == 0 ? OperationType.cut : OperationType.engrave,
        ),
      ));
    }
    final h = cfg.lineCount - 1.0;
    return SvgDocument(
      roots: nodes,
      viewBox: Rect.fromLTWH(0, 0, cfg.widthMm, h),
    );
  }

  void _onFocusTest() {
    final cfg = FocusTestConfig(
      powerPercent: _machineSettings.engravePower,
      speedMmMin: _machineSettings.engraveSpeed,
    );
    setState(() {
      _showKerfTest = false;
      _showFocusTest = true;
      _focusTestConfig = cfg;
      _focusTestDocument = _buildFocusTestDocument(cfg);
    });
  }

  void _onFocusTestChanged(FocusTestConfig cfg) {
    setState(() {
      _focusTestConfig = cfg;
      _focusTestDocument = _buildFocusTestDocument(cfg);
    });
  }

  void _onCloseFocusTest() {
    setState(() => _showFocusTest = false);
  }

  void _startFocusTestJob() {
    final gcode = GcodeTemplates.focusTest(
      _focusTestConfig,
      _machineSettings,
    );
    final lines = gcode
        .split('\n')
        .map((l) => l.contains(';')
            ? l.substring(0, l.indexOf(';')).trim()
            : l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return;
    _grbl.startLines(lines);
  }

  SvgDocument _buildKerfTestDocument(KerfTestConfig cfg) {
    final powers = cfg.powerLevels;
    final nodes = <SvgNode>[];
    for (var i = 0; i < cfg.lineCount; i++) {
      final svgY = (cfg.lineCount - 1 - i) * cfg.lineSpacing.toInt();
      final pct = powers[i];
      nodes.add(SvgNode(
        id: 'line_$i',
        label: '$pct% power',
        type: SvgNodeType.path,
        pathData: 'M 0,$svgY L ${cfg.widthMm},$svgY',
        settings: LayerSettings(
          operationType: OperationType.engrave,
        ),
      ));
    }
    final h = (cfg.lineCount - 1) * cfg.lineSpacing;
    return SvgDocument(
      roots: nodes,
      viewBox: Rect.fromLTWH(0, 0, cfg.widthMm, h),
    );
  }

  void _onKerfTest() {
    final cfg = KerfTestConfig(
      maxPowerPercent: _machineSettings.engravePower,
      speedMmMin: _machineSettings.engraveSpeed,
    );
    setState(() {
      _showFocusTest = false;
      _showKerfTest = true;
      _kerfTestConfig = cfg;
      _kerfTestDocument = _buildKerfTestDocument(cfg);
    });
  }

  void _onKerfTestChanged(KerfTestConfig cfg) {
    setState(() {
      _kerfTestConfig = cfg;
      _kerfTestDocument = _buildKerfTestDocument(cfg);
    });
  }

  void _onCloseKerfTest() {
    setState(() => _showKerfTest = false);
  }

  void _startKerfTestJob() {
    final gcode = GcodeTemplates.kerfTest(
      _kerfTestConfig,
      _machineSettings,
    );
    final lines = gcode
        .split('\n')
        .map((l) => l.contains(';')
            ? l.substring(0, l.indexOf(';')).trim()
            : l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return;
    _grbl.startLines(lines);
  }

  SvgDocument _buildSpotTestDocument(SpotTestConfig cfg) {
    const labels = ['−0.1 mm', 'exact', '+0.1 mm'];
    const bandH = 3.0;
    const w = 9.0;
    final h = bandH * 3;
    final nodes = <SvgNode>[];
    for (var i = 0; i < 3; i++) {
      final svgY = (2 - i) * bandH;
      nodes.add(SvgNode(
        id: 'band_$i',
        label: labels[i],
        type: SvgNodeType.path,
        pathData:
            'M 0,$svgY L $w,$svgY L $w,${svgY + bandH} L 0,${svgY + bandH} Z',
        settings: LayerSettings(operationType: OperationType.engrave),
      ));
    }
    return SvgDocument(
      roots: nodes,
      viewBox: Rect.fromLTWH(0, 0, w, h),
    );
  }

  void _onSpotTest() {
    final cfg = SpotTestConfig(
      powerPercent: _machineSettings.engravePower,
      speedMmMin: _machineSettings.engraveSpeed,
    );
    setState(() {
      _showFocusTest = false;
      _showKerfTest = false;
      _showSpotTest = true;
      _spotTestConfig = cfg;
      _spotTestDocument = _buildSpotTestDocument(cfg);
    });
  }

  void _onSpotTestChanged(SpotTestConfig cfg) {
    setState(() {
      _spotTestConfig = cfg;
    });
  }

  void _onCloseSpotTest() {
    setState(() => _showSpotTest = false);
  }

  void _startSpotTestJob() {
    final gcode = GcodeTemplates.spotTest(
      _spotTestConfig,
      _machineSettings,
    );
    final lines = gcode
        .split('\n')
        .map((l) => l.contains(';')
            ? l.substring(0, l.indexOf(';')).trim()
            : l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return;
    _grbl.startLines(lines);
  }

  // ── Node selection ───────────────────────────────────────────────

  void _toggleEnabled(SvgNode node) {
    setState(() {
      node.enabled = !node.enabled;
      if (_document != null) _toolpath = computeToolpath(_document!, _machineSettings);
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
      if (_document != null) _toolpath = computeToolpath(_document!, _machineSettings);
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
            onFocusTest: _onFocusTest,
            onKerfTest: _onKerfTest,
            onSpotTest: _onSpotTest,
            isConnected: _grbl.connected,
            isSerialConnected: _grbl is GrblSerialService && _grbl.connected,
            onToggleConnect: () => _openConnectDialog(),
            onMachineSettings: _openMachineSettings,
            onAbout: _onAbout,
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
                        showFocusTest: _showFocusTest,
                        focusTestConfig: _focusTestConfig,
                        onFocusTestChanged: _onFocusTestChanged,
                        onFocusTestClose: _onCloseFocusTest,
                        showKerfTest: _showKerfTest,
                        kerfTestConfig: _kerfTestConfig,
                        onKerfTestChanged: _onKerfTestChanged,
                        onKerfTestClose: _onCloseKerfTest,
                        showSpotTest: _showSpotTest,
                        spotTestConfig: _spotTestConfig,
                        onSpotTestChanged: _onSpotTestChanged,
                        onSpotTestClose: _onCloseSpotTest,
                      ),
                    ),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(
                      child: SvgPreviewWidget(
                        document: _showFocusTest
                            ? _focusTestDocument
                            : _showKerfTest
                                ? _kerfTestDocument
                                : _showSpotTest
                                    ? _spotTestDocument
                                    : _document,
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
                        document: _showFocusTest
                            ? _focusTestDocument
                            : _showKerfTest
                                ? _kerfTestDocument
                                : _showSpotTest
                                    ? _spotTestDocument
                                    : _document,
                        service: _grbl,
                        onToggleConnect: _openConnectDialog,
                        onStartJob: _showFocusTest
                            ? _startFocusTestJob
                            : _showKerfTest
                                ? _startKerfTestJob
                                : _showSpotTest
                                    ? _startSpotTestJob
                                    : null,
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
