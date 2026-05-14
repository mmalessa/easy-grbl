import 'package:flutter/material.dart';
import '../models/machine_settings.dart';
import '../models/operation_type.dart';

const _kBaudRates = [9600, 19200, 38400, 57600, 115200, 230400, 250000];
const _kSpeedMin = 100;
const _kSpeedMax = 30000;

Future<MachineSettings?> showMachineSettingsDialog(
  BuildContext context,
  MachineSettings current,
) {
  return showDialog<MachineSettings>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _MachineSettingsDialog(current: current),
  );
}

class _MachineSettingsDialog extends StatefulWidget {
  final MachineSettings current;
  const _MachineSettingsDialog({required this.current});

  @override
  State<_MachineSettingsDialog> createState() => _MachineSettingsDialogState();
}

class _MachineSettingsDialogState extends State<_MachineSettingsDialog> {
  late LaserMode _laserMode;
  late TextEditingController _sMaxCtrl;
  late TextEditingController _spotCtrl;
  late double _engravePower;
  late TextEditingController _engraveSpeedCtrl;
  late double _cutPower;
  late TextEditingController _cutSpeedCtrl;
  late double _fillPower;
  late TextEditingController _fillSpeedCtrl;
  late int _baudRate;

  @override
  void initState() {
    super.initState();
    final s = widget.current;
    _laserMode = s.laserMode;
    _sMaxCtrl = TextEditingController(text: '${s.sMax}');
    _spotCtrl = TextEditingController(text: s.laserSpotSize.toStringAsFixed(2));
    _engravePower = s.engravePower.toDouble();
    _engraveSpeedCtrl = TextEditingController(text: '${s.engraveSpeed}');
    _cutPower = s.cutPower.toDouble();
    _cutSpeedCtrl = TextEditingController(text: '${s.cutSpeed}');
    _fillPower = s.fillPower.toDouble();
    _fillSpeedCtrl = TextEditingController(text: '${s.fillSpeed}');
    _baudRate = s.defaultBaudRate;
  }

  @override
  void dispose() {
    _sMaxCtrl.dispose();
    _spotCtrl.dispose();
    _engraveSpeedCtrl.dispose();
    _cutSpeedCtrl.dispose();
    _fillSpeedCtrl.dispose();
    super.dispose();
  }

  int? _parseSpeed(TextEditingController ctrl) {
    final v = int.tryParse(ctrl.text.trim());
    if (v == null || v < _kSpeedMin || v > _kSpeedMax) return null;
    return v;
  }

  bool get _isValid =>
      _parseSpeed(_engraveSpeedCtrl) != null &&
      _parseSpeed(_cutSpeedCtrl) != null &&
      _parseSpeed(_fillSpeedCtrl) != null;

  MachineSettings _buildResult() {
    final spot = double.tryParse(_spotCtrl.text.replaceAll(',', '.')) ??
        widget.current.laserSpotSize;
    final sMax =
        int.tryParse(_sMaxCtrl.text.trim()) ?? widget.current.sMax;
    return MachineSettings(
      laserMode: _laserMode,
      sMax: sMax.clamp(1, 100000),
      laserSpotSize: spot.clamp(0.01, 10.0),
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
      defaultBaudRate: _baudRate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge(
          [_engraveSpeedCtrl, _cutSpeedCtrl, _fillSpeedCtrl]),
      builder: (context, _) => AlertDialog(
        title: Row(children: [
          Icon(Icons.settings, size: 18, color: cs.onSurface.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Text('Machine Settings',
              style: TextStyle(color: cs.onSurface, fontSize: 15)),
        ]),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _sectionHeader('LASER', cs),
                _laserModeSelector(cs),
                const SizedBox(height: 14),
                _sMaxRow(cs),
                const SizedBox(height: 14),
                _spotSizeRow(cs),

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
                    children: [
                      _defaultRow(OperationType.cut, _cutPower,
                          _cutSpeedCtrl, (v) => setState(() => _cutPower = v), cs),
                      const SizedBox(height: 10),
                      _defaultRow(OperationType.fill, _fillPower,
                          _fillSpeedCtrl, (v) => setState(() => _fillPower = v), cs),
                      const SizedBox(height: 10),
                      _defaultRow(OperationType.engrave, _engravePower,
                          _engraveSpeedCtrl, (v) => setState(() => _engravePower = v), cs),
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

  Widget _numericField(TextEditingController ctrl,
          {required double width, required bool decimal, required ColorScheme cs}) =>
      SizedBox(
        width: width,
        child: TextField(
          controller: ctrl,
          style: TextStyle(color: cs.onSurface, fontSize: 13),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            filled: true,
            fillColor: cs.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: cs.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: cs.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: cs.primary),
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
