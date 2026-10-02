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
import '../../services/gcode_format.dart';
import '../../machines/gcode/gcode_generator.dart';
import '../../machines/laser/templates/laser_gcode_templates.dart';
import '../../services/toolpath.dart';
import '../../machines/machine_settings.dart';
import '../../machines/machine_mode.dart';
import '../../machines/laser/templates/focus_test.dart';
import '../../machines/laser/templates/kerf_test.dart';
import '../../machines/laser/templates/spot_test.dart';
import '../../machines/laser/templates/test_session.dart';
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

  // At most one template test (Focus/Kerf/Spot) is active at a time.
  TestSession _testSession = const NoTestSession();

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
      setState(() {
        _machineSettings = result;
        if (_document != null) _toolpath = computeToolpath(_document!, result);
      });
      _grbl.machineSettings = result;
      SettingsService.save(result);
    }
  }

  // ── Working mode ─────────────────────────────────────────────────

  bool get _jobActive => _grbl.isJobActive;

  Future<void> _onModeChanged(MachineType type) async {
    if (type == _machineSettings.machineType || _jobActive) return;
    if (_document != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Switch to ${type.profile.displayName}?'),
          content: const Text(
              'Layer settings will be interpreted for the new mode.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Switch'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted || _jobActive) return;
    }
    final updated = _machineSettings.copyWith(machineType: type);
    setState(() {
      _machineSettings = updated;
      if (_document != null) _toolpath = computeToolpath(_document!, updated);
      if (!type.profile.supportsTemplates) {
        _testSession = const NoTestSession();
      }
    });
    _grbl.machineSettings = updated;
    SettingsService.save(updated);
  }

  /// Compares the connected device's GRBL $32 laser-mode flag with the app's
  /// mode and offers to sync the device when they disagree. Never changes the
  /// app's mode.
  Future<void> _checkDeviceMode(GrblService grbl) async {
    // Many GRBL boards reset when the serial port opens and ignore commands
    // until they have booted.
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted || !identical(grbl, _grbl) || !grbl.connected || _jobActive) {
      return;
    }
    final device = await grbl.queryMachineType();
    final wanted = _machineSettings.machineType;
    if (!mounted || device == null || device == wanted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 15),
      content: Text(
          'Device is configured as ${device.profile.displayName} '
          '(\$32=${device == MachineType.laser ? 1 : 0}), '
          'app is in ${wanted.profile.displayName} mode.'),
      action: SnackBarAction(
        label: 'Sync device',
        onPressed: () async {
          // The SnackBar outlives the state it was shown in: a job may have
          // started, the connection changed, or the app mode been switched.
          if (!mounted || !identical(grbl, _grbl) || !grbl.connected) return;
          if (grbl.isJobActive) {
            messenger.showSnackBar(const SnackBar(
                content: Text('Cannot sync the device while a job is running')));
            return;
          }
          final target = _machineSettings.machineType;
          final ok = await grbl.setDeviceLaserMode(target == MachineType.laser);
          messenger.showSnackBar(SnackBar(
            content: Text(ok
                ? 'Device set to ${target.profile.displayName}'
                : 'Failed to update device configuration'),
          ));
        },
      ),
    ));
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
      initialBaud: _machineSettings.common.defaultBaudRate,
    );
    if (result == null || !mounted) return;

    if (result.mock) {
      if (_grbl is GrblMockService && _grbl.connected) return; // already connected
      if (_grbl is GrblMockService) {
        (_grbl as GrblMockService).connect(); // reconnect existing mock
        _checkDeviceMode(_grbl);
        return;
      }
      final old = _grbl;
      final mock = GrblMockService()..connect();
      mock.machineSettings = _machineSettings;
      setState(() => _grbl = mock);
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      _checkDeviceMode(mock);
    } else {
      final serial = GrblSerialService();
      final ok = await serial.connectSerial(result.port!, result.baud);
      if (!mounted) return;
      if (ok) {
        final old = _grbl;
        serial.machineSettings = _machineSettings;
        setState(() => _grbl = serial);
        WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
        _checkDeviceMode(serial);
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

  void _onFocusTest() {
    final cfg = FocusTestConfig(
      powerPercent: _machineSettings.laser.engravePower,
      speedMmMin: _machineSettings.laser.engraveSpeed,
    );
    setState(() =>
        _testSession = FocusTestSession(cfg, buildFocusTestDocument(cfg)));
  }

  void _onFocusTestChanged(FocusTestConfig cfg) {
    setState(() =>
        _testSession = FocusTestSession(cfg, buildFocusTestDocument(cfg)));
  }

  void _onKerfTest() {
    final cfg = KerfTestConfig(
      maxPowerPercent: _machineSettings.laser.engravePower,
      speedMmMin: _machineSettings.laser.engraveSpeed,
    );
    setState(() =>
        _testSession = KerfTestSession(cfg, buildKerfTestDocument(cfg)));
  }

  void _onKerfTestChanged(KerfTestConfig cfg) {
    setState(() =>
        _testSession = KerfTestSession(cfg, buildKerfTestDocument(cfg)));
  }

  void _onSpotTest() {
    final cfg = SpotTestConfig(
      powerPercent: _machineSettings.laser.engravePower,
      speedMmMin: _machineSettings.laser.engraveSpeed,
    );
    setState(() =>
        _testSession = SpotTestSession(cfg, buildSpotTestDocument()));
  }

  void _onSpotTestChanged(SpotTestConfig cfg) {
    // The Spot Test document's geometry doesn't depend on power/speed, so
    // keep the existing document instead of rebuilding it on every change.
    final session = _testSession;
    if (session is! SpotTestSession) return;
    setState(() => _testSession = SpotTestSession(cfg, session.document));
  }

  void _onCloseTest() {
    setState(() => _testSession = const NoTestSession());
  }

  void _startTestJob() {
    final gcode = switch (_testSession) {
      NoTestSession() => null,
      FocusTestSession(:final config) =>
        LaserGcodeTemplates.focusTest(config, _machineSettings.laser),
      KerfTestSession(:final config) =>
        LaserGcodeTemplates.kerfTest(config, _machineSettings.laser),
      SpotTestSession(:final config) =>
        LaserGcodeTemplates.spotTest(config, _machineSettings.laser),
    };
    if (gcode == null) return;
    final lines = stripGcodeComments(gcode);
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
    final testDocument = switch (_testSession) {
      NoTestSession() => null,
      FocusTestSession(:final document) => document,
      KerfTestSession(:final document) => document,
      SpotTestSession(:final document) => document,
    };
    final previewDocument = testDocument ?? _document;
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
            machineType: _machineSettings.machineType,
            onModeChanged: _jobActive ? null : _onModeChanged,
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
                        testSession: _testSession,
                        onFocusTestChanged: _onFocusTestChanged,
                        onKerfTestChanged: _onKerfTestChanged,
                        onSpotTestChanged: _onSpotTestChanged,
                        onCloseTest: _onCloseTest,
                      ),
                    ),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(
                      child: SvgPreviewWidget(
                        document: previewDocument,
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
                        document: previewDocument,
                        service: _grbl,
                        machineType: _machineSettings.machineType,
                        onToggleConnect: _openConnectDialog,
                        onStartJob: _testSession is NoTestSession
                            ? null
                            : _startTestJob,
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
