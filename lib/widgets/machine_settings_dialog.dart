import 'package:flutter/material.dart';
import '../models/machine_settings.dart';
import '../models/operation_type.dart';
import '../services/grbl_service.dart';

const _kBaudRates = [9600, 19200, 38400, 57600, 115200, 230400, 250000];
const _kSpeedMin = 100;
const _kSpeedMax = 30000;

Future<MachineSettings?> showMachineSettingsDialog(
  BuildContext context,
  MachineSettings current,
  GrblService grbl,
) {
  return showDialog<MachineSettings>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _MachineSettingsDialog(current: current, grbl: grbl),
  );
}

class _MachineSettingsDialog extends StatefulWidget {
  final MachineSettings current;
  final GrblService grbl;
  const _MachineSettingsDialog({required this.current, required this.grbl});

  @override
  State<_MachineSettingsDialog> createState() => _MachineSettingsDialogState();
}

class _MachineSettingsDialogState extends State<_MachineSettingsDialog> {
  late MachineType _machineType;
  late LaserMode _laserMode;
  late TextEditingController _sMaxCtrl;
  late TextEditingController _spotCtrl;
  late TextEditingController _maxSpindleSpeedCtrl;
  late TextEditingController _maxFeedRateCtrl;
  late TextEditingController _toolDiamCtrl;
  late TextEditingController _bladeAngleCtrl;
  late TextEditingController _safeHeightCtrl;
  late TextEditingController _travelFeedRateCtrl;
  late double _engravePower;
  late TextEditingController _engraveSpeedCtrl;
  late double _cutPower;
  late TextEditingController _cutSpeedCtrl;
  late double _fillPower;
  late TextEditingController _fillSpeedCtrl;
  late TextEditingController _engraveSpindleCtrl;
  late TextEditingController _engraveFeedCtrl;
  late TextEditingController _cutSpindleCtrl;
  late TextEditingController _cutFeedCtrl;
  late TextEditingController _fillSpindleCtrl;
  late TextEditingController _fillFeedCtrl;
  late int _baudRate;

  bool _queryingDevice = false;
  MachineType? _deviceMachineType;

  @override
  void initState() {
    super.initState();
    final s = widget.current;
    _machineType = s.machineType;
    _laserMode = s.laserMode;
    _sMaxCtrl = TextEditingController(text: '${s.sMax}');
    _spotCtrl = TextEditingController(text: s.laserSpotSize.toStringAsFixed(2));
    _maxSpindleSpeedCtrl = TextEditingController(text: '${s.maxSpindleSpeed}');
    _maxFeedRateCtrl = TextEditingController(text: s.maxFeedRate.toStringAsFixed(1));
    _toolDiamCtrl = TextEditingController(text: s.toolDiameter.toStringAsFixed(3));
    _bladeAngleCtrl = TextEditingController(text: s.bladeAngle.toStringAsFixed(1));
    _safeHeightCtrl = TextEditingController(text: s.safeHeight.toStringAsFixed(1));
    _travelFeedRateCtrl = TextEditingController(text: s.travelFeedRate.toStringAsFixed(1));
    _engravePower = s.engravePower.toDouble();
    _engraveSpeedCtrl = TextEditingController(text: '${s.engraveSpeed}');
    _cutPower = s.cutPower.toDouble();
    _cutSpeedCtrl = TextEditingController(text: '${s.cutSpeed}');
    _fillPower = s.fillPower.toDouble();
    _fillSpeedCtrl = TextEditingController(text: '${s.fillSpeed}');
    _engraveSpindleCtrl = TextEditingController(text: '${s.engraveSpindleSpeed}');
    _engraveFeedCtrl = TextEditingController(text: s.engraveFeedRate.toStringAsFixed(1));
    _cutSpindleCtrl = TextEditingController(text: '${s.cutSpindleSpeed}');
    _cutFeedCtrl = TextEditingController(text: s.cutFeedRate.toStringAsFixed(1));
    _fillSpindleCtrl = TextEditingController(text: '${s.fillSpindleSpeed}');
    _fillFeedCtrl = TextEditingController(text: s.fillFeedRate.toStringAsFixed(1));
    _baudRate = s.defaultBaudRate;

    if (widget.grbl.connected) {
      _queryingDevice = true;
      widget.grbl.queryMachineType().then((type) {
        if (!mounted) return;
        setState(() {
          _deviceMachineType = type;
          _queryingDevice = false;
        });
        _checkDeviceSync();
      });
    }
  }

  // ── Device sync check ──────────────────────────────────────────────
  // Compares the app-side MACHINE TYPE selection against what the
  // connected device actually reports, offering to push the change to
  // the device's GRBL $32 setting when they disagree.

  bool _syncPromptOpen = false;

  Future<void> _checkDeviceSync() async {
    if (!widget.grbl.connected) return;
    if (_deviceMachineType == null || _deviceMachineType == _machineType) return;
    if (_syncPromptOpen) return;
    _syncPromptOpen = true;
    final wanted = _machineType;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Machine type mismatch'),
        content: Text(
          'The connected device is configured as ${_deviceMachineType!.label}, '
          'but the app is set to ${wanted.label}.\n\n'
          'Update the device configuration to ${wanted.label}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    _syncPromptOpen = false;
    if (confirmed != true || !mounted) return;
    final ok = await widget.grbl.setDeviceLaserMode(wanted == MachineType.laser);
    if (!mounted) return;
    if (ok) {
      setState(() => _deviceMachineType = wanted);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update device configuration')),
      );
    }
  }

  @override
  void dispose() {
    _sMaxCtrl.dispose();
    _spotCtrl.dispose();
    _maxSpindleSpeedCtrl.dispose();
    _maxFeedRateCtrl.dispose();
    _toolDiamCtrl.dispose();
    _bladeAngleCtrl.dispose();
    _safeHeightCtrl.dispose();
    _travelFeedRateCtrl.dispose();
    _engraveSpeedCtrl.dispose();
    _cutSpeedCtrl.dispose();
    _fillSpeedCtrl.dispose();
    _engraveSpindleCtrl.dispose();
    _engraveFeedCtrl.dispose();
    _cutSpindleCtrl.dispose();
    _cutFeedCtrl.dispose();
    _fillSpindleCtrl.dispose();
    _fillFeedCtrl.dispose();
    super.dispose();
  }

  int? _parseSpeed(TextEditingController ctrl) {
    final v = int.tryParse(ctrl.text.trim());
    if (v == null || v < _kSpeedMin || v > _kSpeedMax) return null;
    return v;
  }

  int? _parsePositiveInt(TextEditingController ctrl) {
    final v = int.tryParse(ctrl.text.trim());
    if (v == null || v <= 0) return null;
    return v;
  }

  double? _parsePositiveDouble(TextEditingController ctrl) {
    final v = double.tryParse(ctrl.text.replaceAll(',', '.'));
    if (v == null || v <= 0) return null;
    return v;
  }

  bool get _isValid {
    final speedsOk = _parseSpeed(_engraveSpeedCtrl) != null &&
        _parseSpeed(_cutSpeedCtrl) != null &&
        _parseSpeed(_fillSpeedCtrl) != null;
    if (_machineType == MachineType.mill) {
      final millParamsOk = _parsePositiveInt(_maxSpindleSpeedCtrl) != null &&
          _parsePositiveDouble(_maxFeedRateCtrl) != null &&
          _parsePositiveDouble(_toolDiamCtrl) != null &&
          _parsePositiveDouble(_bladeAngleCtrl) != null &&
          _parsePositiveDouble(_safeHeightCtrl) != null &&
          _parsePositiveDouble(_travelFeedRateCtrl) != null;
      final millDefaultsOk =
          _parsePositiveInt(_cutSpindleCtrl) != null &&
          _parsePositiveDouble(_cutFeedCtrl) != null &&
          _parsePositiveInt(_fillSpindleCtrl) != null &&
          _parsePositiveDouble(_fillFeedCtrl) != null &&
          _parsePositiveInt(_engraveSpindleCtrl) != null &&
          _parsePositiveDouble(_engraveFeedCtrl) != null;
      return millParamsOk && millDefaultsOk;
    }
    return speedsOk;
  }

  MachineSettings _buildResult() {
    final spot = double.tryParse(_spotCtrl.text.replaceAll(',', '.')) ??
        widget.current.laserSpotSize;
    final sMax = int.tryParse(_sMaxCtrl.text.trim()) ?? widget.current.sMax;
    final maxSpindleSpeed = _parsePositiveInt(_maxSpindleSpeedCtrl) ?? widget.current.maxSpindleSpeed;
    final maxFeedRate = _parsePositiveDouble(_maxFeedRateCtrl) ?? widget.current.maxFeedRate;
    final toolDiam = _parsePositiveDouble(_toolDiamCtrl) ?? widget.current.toolDiameter;
    final bladeAngle = _parsePositiveDouble(_bladeAngleCtrl) ?? widget.current.bladeAngle;
    final safeHeight = _parsePositiveDouble(_safeHeightCtrl) ?? widget.current.safeHeight;
    final travelFeedRate = _parsePositiveDouble(_travelFeedRateCtrl) ?? widget.current.travelFeedRate;
    return MachineSettings(
      machineType: _machineType,
      laserMode: _laserMode,
      sMax: sMax.clamp(1, 100000),
      laserSpotSize: spot.clamp(0.01, 10.0),
      maxSpindleSpeed: maxSpindleSpeed.clamp(1, 1000000),
      maxFeedRate: maxFeedRate.clamp(0.1, 100000.0),
      toolDiameter: toolDiam.clamp(0.1, 100.0),
      bladeAngle: bladeAngle.clamp(1.0, 180.0),
      safeHeight: safeHeight.clamp(0.1, 500.0),
      travelFeedRate: travelFeedRate.clamp(1.0, 100000.0),
      engravePower: _engravePower.round(),
      engraveSpeed:
          (_parseSpeed(_engraveSpeedCtrl) ?? widget.current.engraveSpeed)
              .clamp(_kSpeedMin, _kSpeedMax),
      cutPower: _cutPower.round(),
      cutSpeed: (_parseSpeed(_cutSpeedCtrl) ?? widget.current.cutSpeed)
          .clamp(_kSpeedMin, _kSpeedMax),
      fillPower: _fillPower.round(),
      fillSpeed: (_parseSpeed(_fillSpeedCtrl) ?? widget.current.fillSpeed)
          .clamp(_kSpeedMin, _kSpeedMax),
      engraveSpindleSpeed: (_parsePositiveInt(_engraveSpindleCtrl) ?? widget.current.engraveSpindleSpeed).clamp(1, 1000000),
      engraveFeedRate: (_parsePositiveDouble(_engraveFeedCtrl) ?? widget.current.engraveFeedRate).clamp(0.1, 10000.0),
      cutSpindleSpeed: (_parsePositiveInt(_cutSpindleCtrl) ?? widget.current.cutSpindleSpeed).clamp(1, 1000000),
      cutFeedRate: (_parsePositiveDouble(_cutFeedCtrl) ?? widget.current.cutFeedRate).clamp(0.1, 10000.0),
      fillSpindleSpeed: (_parsePositiveInt(_fillSpindleCtrl) ?? widget.current.fillSpindleSpeed).clamp(1, 1000000),
      fillFeedRate: (_parsePositiveDouble(_fillFeedCtrl) ?? widget.current.fillFeedRate).clamp(0.1, 10000.0),
      defaultBaudRate: _baudRate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([
        _engraveSpeedCtrl, _cutSpeedCtrl, _fillSpeedCtrl,
        _maxSpindleSpeedCtrl, _maxFeedRateCtrl,
        _toolDiamCtrl, _bladeAngleCtrl,
        _safeHeightCtrl, _travelFeedRateCtrl,
        _engraveSpindleCtrl, _engraveFeedCtrl,
        _cutSpindleCtrl, _cutFeedCtrl,
        _fillSpindleCtrl, _fillFeedCtrl,
      ]),
      builder: (context, _) => AlertDialog(
        title: Row(children: [
          Icon(Icons.settings, size: 18, color: cs.onSurface.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Text('Machine Settings',
              style: TextStyle(color: cs.onSurface, fontSize: 15)),
        ]),
        content: SizedBox(
          width: 570,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _connectionStatusRow(cs),
                const SizedBox(height: 20),

                _sectionHeader('MACHINE TYPE', cs),
                _machineTypeSelector(cs),

                const SizedBox(height: 20),
                if (_machineType == MachineType.laser) ...[
                  _sectionHeader('LASER', cs),
                  _laserModeSelector(cs),
                  const SizedBox(height: 14),
                  _sMaxRow(cs),
                  const SizedBox(height: 14),
                  _spotSizeRow(cs),
                ] else ...[
                  _sectionHeader('MILL', cs),
                  _maxSpindleSpeedRow(cs),
                  const SizedBox(height: 14),
                  _maxFeedRateRow(cs),
                  const SizedBox(height: 14),
                  _toolDiamRow(cs),
                  const SizedBox(height: 14),
                  _bladeAngleRow(cs),
                  const SizedBox(height: 14),
                  _safeHeightRow(cs),
                  const SizedBox(height: 14),
                  _travelFeedRateRow(cs),
                ],

                const SizedBox(height: 20),
                _sectionHeader('DEFAULTS', cs),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: _machineType == MachineType.laser
                        ? [
                            _defaultRow(OperationType.cut, _cutPower,
                                _cutSpeedCtrl, (v) => setState(() => _cutPower = v), cs),
                            const SizedBox(height: 10),
                            _defaultRow(OperationType.fill, _fillPower,
                                _fillSpeedCtrl, (v) => setState(() => _fillPower = v), cs),
                            const SizedBox(height: 10),
                            _defaultRow(OperationType.engrave, _engravePower,
                                _engraveSpeedCtrl, (v) => setState(() => _engravePower = v), cs),
                          ]
                        : [
                            _millDefaultRow(OperationType.cut, _cutSpindleCtrl, _cutFeedCtrl, cs),
                            const SizedBox(height: 10),
                            _millDefaultRow(OperationType.fill, _fillSpindleCtrl, _fillFeedCtrl, cs),
                            const SizedBox(height: 10),
                            _millDefaultRow(OperationType.engrave, _engraveSpindleCtrl, _engraveFeedCtrl, cs),
                          ],
                  ),
                ),

                const SizedBox(height: 20),
                _sectionHeader('CONNECTION', cs),
                _baudRateRow(cs),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed:
                _isValid ? () => Navigator.pop(context, _buildResult()) : null,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _connectionStatusRow(ColorScheme cs) {
    final connected = widget.grbl.connected;
    final statusColor = connected ? const Color(0xFF388E3C) : cs.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            connected ? 'Connected' : 'Disconnected',
            style: TextStyle(
                color: cs.onSurface, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          if (connected) ...[
            const SizedBox(width: 10),
            Container(width: 1, height: 12, color: cs.outlineVariant),
            const SizedBox(width: 10),
            if (_queryingDevice)
              Text('Detecting device type…',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))
            else if (_deviceMachineType == null)
              Text('Device type unknown',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))
            else ...[
              Icon(
                _deviceMachineType == MachineType.laser
                    ? Icons.flash_on
                    : Icons.build,
                size: 14,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                'Device configured as: ${_deviceMachineType!.label}',
                style: TextStyle(
                    color: cs.onSurface, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, ColorScheme cs) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          title,
          style: TextStyle(
              fontSize: 10,
              color: cs.onSurfaceVariant,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600),
        ),
      );

  Widget _fieldLabel(String text, ColorScheme cs) => Text(
        text,
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
      );

  Widget _machineTypeSelector(ColorScheme cs) => Row(
        children: MachineType.values.map((m) {
          final sel = m == _machineType;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _machineType = m);
                _checkDeviceSync();
              },
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: sel
                      ? cs.primary.withValues(alpha: 0.25)
                      : cs.surfaceContainerHighest,
                  border: Border.all(
                    color: sel ? cs.primary : cs.outlineVariant,
                    width: sel ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  m.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: sel ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );

  Widget _laserModeSelector(ColorScheme cs) => Row(
        children: LaserMode.values.map((m) {
          final sel = m == _laserMode;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _laserMode = m),
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: sel
                      ? cs.primary.withValues(alpha: 0.25)
                      : cs.surfaceContainerHighest,
                  border: Border.all(
                    color: sel ? cs.primary : cs.outlineVariant,
                    width: sel ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  m.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: sel ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );

  Widget _millDefaultRow(OperationType type,
      TextEditingController spindleCtrl, TextEditingController feedCtrl,
      ColorScheme cs) {
    final color = type.color;
    final spindleOk = _parsePositiveInt(spindleCtrl) != null;
    final feedOk = _parsePositiveDouble(feedCtrl) != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            type.label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5),
          ),
        ),
        Row(
          children: [
            Text('Spindle speed',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
            const SizedBox(width: 4),
            _stepBtn(Icons.remove, color, () {
              final v = int.tryParse(spindleCtrl.text.trim()) ?? 1000;
              spindleCtrl.text = '${(v - 1000).clamp(100, 1000000)}';
            }),
            const SizedBox(width: 2),
            SizedBox(
              width: 60,
              child: TextField(
                controller: spindleCtrl,
                style: TextStyle(
                    color: spindleOk ? cs.onSurface : cs.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                decoration: _compactFieldDecoration(spindleOk, cs),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 2),
            _stepBtn(Icons.add, color, () {
              final v = int.tryParse(spindleCtrl.text.trim()) ?? 1000;
              spindleCtrl.text = '${(v + 1000).clamp(100, 1000000)}';
            }),
            const SizedBox(width: 4),
            Text('RPM', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
            const Spacer(),
            Text('Feed rate',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
            const SizedBox(width: 4),
            _stepBtn(Icons.remove, color, () {
              final v = double.tryParse(feedCtrl.text.replaceAll(',', '.')) ?? 5.0;
              feedCtrl.text = ((v - 5.0).clamp(0.1, 10000.0)).toStringAsFixed(1);
            }),
            const SizedBox(width: 2),
            SizedBox(
              width: 52,
              child: TextField(
                controller: feedCtrl,
                style: TextStyle(
                    color: feedOk ? cs.onSurface : cs.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                decoration: _compactFieldDecoration(feedOk, cs),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 2),
            _stepBtn(Icons.add, color, () {
              final v = double.tryParse(feedCtrl.text.replaceAll(',', '.')) ?? 5.0;
              feedCtrl.text = ((v + 5.0).clamp(0.1, 10000.0)).toStringAsFixed(1);
            }),
            const SizedBox(width: 4),
            Text('mm/s', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
          ],
        ),
      ],
    );
  }

  InputDecoration _compactFieldDecoration(bool valid, ColorScheme cs) =>
      InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: valid ? cs.outline : cs.error),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: valid ? cs.outline : cs.error),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: valid ? cs.primary : cs.error),
        ),
      );

  Widget _defaultRow(OperationType type, double power,
      TextEditingController speedCtrl, ValueChanged<double> onPowerChanged,
      ColorScheme cs) {
    final color = type.color;
    final valid = _parseSpeed(speedCtrl) != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            type.label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5),
          ),
        ),
        Row(
          children: [
            Text('Power',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
            const SizedBox(width: 6),
            SizedBox(
              width: 90,
              height: 24,
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: color,
                  thumbColor: color,
                  overlayColor: color.withValues(alpha: 0.15),
                  inactiveTrackColor: cs.surfaceContainerHighest,
                  trackHeight: 2,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 5),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 10),
                ),
                child: Slider(
                  value: power,
                  min: 0,
                  max: 100,
                  divisions: 100,
                  onChanged: onPowerChanged,
                ),
              ),
            ),
            SizedBox(
              width: 30,
              child: Text(
                '${power.round()}%',
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Text('Speed',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
            const SizedBox(width: 4),
            _stepBtn(Icons.remove, color, () {
              final v = int.tryParse(speedCtrl.text.trim()) ?? _kSpeedMin;
              speedCtrl.text =
                  '${(v - 100).clamp(_kSpeedMin, _kSpeedMax)}';
            }),
            const SizedBox(width: 2),
            SizedBox(
              width: 56,
              child: TextField(
                controller: speedCtrl,
                style: TextStyle(
                    color: valid ? cs.onSurface : cs.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 5),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(
                        color: valid ? cs.outline : cs.error),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(
                        color: valid ? cs.outline : cs.error),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(
                        color: valid ? cs.primary : cs.error),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 2),
            _stepBtn(Icons.add, color, () {
              final v = int.tryParse(speedCtrl.text.trim()) ?? _kSpeedMin;
              speedCtrl.text =
                  '${(v + 100).clamp(_kSpeedMin, _kSpeedMax)}';
            }),
          ],
        ),
      ],
    );
  }

  Widget _sMaxRow(ColorScheme cs) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('Max laser power (S max)', cs),
                const SizedBox(height: 2),
                Text(
                  'Must match parameter \$30 in GRBL controller',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _numericField(_sMaxCtrl, width: 70, decimal: false, cs: cs),
        ],
      );

  Widget _spotSizeRow(ColorScheme cs) => Row(
        children: [
          _fieldLabel('Laser spot size', cs),
          const Spacer(),
          _numericField(_spotCtrl, width: 64, decimal: true, cs: cs),
          const SizedBox(width: 6),
          Text('mm', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ],
      );

  Widget _maxSpindleSpeedRow(ColorScheme cs) => Row(
        children: [
          _fieldLabel('Max spindle speed', cs),
          const Spacer(),
          _numericField(_maxSpindleSpeedCtrl, width: 80, decimal: false, cs: cs,
              isValid: _parsePositiveInt(_maxSpindleSpeedCtrl) != null),
          const SizedBox(width: 6),
          Text('RPM', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ],
      );

  Widget _maxFeedRateRow(ColorScheme cs) => Row(
        children: [
          _fieldLabel('Max feed rate', cs),
          const Spacer(),
          _numericField(_maxFeedRateCtrl, width: 80, decimal: true, cs: cs,
              isValid: _parsePositiveDouble(_maxFeedRateCtrl) != null),
          const SizedBox(width: 6),
          Text('mm/s', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ],
      );

  Widget _toolDiamRow(ColorScheme cs) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('Tool diameter', cs),
                const SizedBox(height: 2),
                Text(
                  'Diameter of the cutting bit at its widest point',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _numericField(_toolDiamCtrl, width: 72, decimal: true, cs: cs,
              isValid: _parsePositiveDouble(_toolDiamCtrl) != null),
          const SizedBox(width: 6),
          Text('mm', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ],
      );

  Widget _bladeAngleRow(ColorScheme cs) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('Included angle', cs),
                const SizedBox(height: 2),
                Text(
                  'Between the two cutting edges',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _numericField(_bladeAngleCtrl, width: 72, decimal: true, cs: cs,
              isValid: _parsePositiveDouble(_bladeAngleCtrl) != null),
          const SizedBox(width: 6),
          Text('°', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ],
      );

  Widget _safeHeightRow(ColorScheme cs) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('Safe height', cs),
                const SizedBox(height: 2),
                Text(
                  'Z clearance for rapid moves above the material',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _numericField(_safeHeightCtrl, width: 72, decimal: true, cs: cs,
              isValid: _parsePositiveDouble(_safeHeightCtrl) != null),
          const SizedBox(width: 6),
          Text('mm', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ],
      );

  Widget _travelFeedRateRow(ColorScheme cs) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('Travel feed rate', cs),
                const SizedBox(height: 2),
                Text(
                  'Speed for non-cutting moves (retract / travel / plunge)',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _numericField(_travelFeedRateCtrl, width: 72, decimal: true, cs: cs,
              isValid: _parsePositiveDouble(_travelFeedRateCtrl) != null),
          const SizedBox(width: 6),
          Text('mm/s', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        ],
      );

  Widget _numericField(TextEditingController ctrl,
          {required double width,
          required bool decimal,
          required ColorScheme cs,
          bool isValid = true}) =>
      SizedBox(
        width: width,
        child: TextField(
          controller: ctrl,
          style: TextStyle(
              color: isValid ? cs.onSurface : cs.error, fontSize: 13),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            filled: true,
            fillColor: cs.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: isValid ? cs.outline : cs.error),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: isValid ? cs.outline : cs.error),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: isValid ? cs.primary : cs.error),
            ),
          ),
          keyboardType: decimal
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.number,
        ),
      );

  Widget _stepBtn(IconData icon, Color color, VoidCallback onTap) => SizedBox(
        width: 26,
        height: 32,
        child: Material(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: Icon(icon, size: 13, color: color),
          ),
        ),
      );

  Widget _baudRateRow(ColorScheme cs) => Row(
        children: [
          _fieldLabel('Default baud rate', cs),
          const Spacer(),
          DropdownButton<int>(
            value: _baudRate,
            dropdownColor: cs.surfaceContainerHigh,
            style: TextStyle(color: cs.onSurface, fontSize: 13),
            underline: const SizedBox(),
            items: _kBaudRates
                .map((b) => DropdownMenuItem(value: b, child: Text('$b')))
                .toList(),
            onChanged: (v) => setState(() => _baudRate = v!),
          ),
        ],
      );
}
