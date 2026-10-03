import 'package:flutter/material.dart';
import '../../../models/operation_type.dart';
import '../../../models/speed_unit.dart';
import '../../../widgets/settings_form_fields.dart';
import '../laser_settings.dart';

// Laser speeds are stored in mm/min.
const _kSpeedMin = 100;
const _kSpeedMax = 30000;

/// Editable state of the laser part of Machine Settings. Notifies on every
/// change so the dialog can re-validate.
class LaserSettingsForm extends ChangeNotifier {
  LaserSettingsForm(LaserSettings s, [SpeedUnit unit = SpeedUnit.mmPerSec])
      : _laserMode = s.laserMode,
        sMaxCtrl = TextEditingController(text: '${s.sMax}'),
        spotCtrl =
            TextEditingController(text: s.laserSpotSize.toStringAsFixed(2)),
        _engravePower = s.engravePower.toDouble(),
        engraveSpeedCtrl = SpeedTextController(s.engraveSpeed / 60.0, unit),
        _cutPower = s.cutPower.toDouble(),
        cutSpeedCtrl = SpeedTextController(s.cutSpeed / 60.0, unit),
        _fillPower = s.fillPower.toDouble(),
        fillSpeedCtrl = SpeedTextController(s.fillSpeed / 60.0, unit) {
    for (final c in _controllers) {
      c.addListener(notifyListeners);
    }
  }

  final TextEditingController sMaxCtrl;
  final TextEditingController spotCtrl;
  final SpeedTextController engraveSpeedCtrl;
  final SpeedTextController cutSpeedCtrl;
  final SpeedTextController fillSpeedCtrl;
  LaserMode _laserMode;
  double _engravePower;
  double _cutPower;
  double _fillPower;

  List<TextEditingController> get _controllers =>
      [sMaxCtrl, spotCtrl, engraveSpeedCtrl, cutSpeedCtrl, fillSpeedCtrl];

  List<SpeedTextController> get _speedCtrls =>
      [engraveSpeedCtrl, cutSpeedCtrl, fillSpeedCtrl];

  SpeedUnit get speedUnit => engraveSpeedCtrl.unit;
  set speedUnit(SpeedUnit u) {
    for (final c in _speedCtrls) {
      c.unit = u;
    }
  }

  LaserMode get laserMode => _laserMode;
  set laserMode(LaserMode v) {
    _laserMode = v;
    notifyListeners();
  }

  double powerFor(OperationType op) => switch (op) {
        OperationType.engrave => _engravePower,
        OperationType.cut => _cutPower,
        OperationType.fill => _fillPower,
        OperationType.skip => 0,
      };

  void setPower(OperationType op, double v) {
    switch (op) {
      case OperationType.engrave:
        _engravePower = v;
      case OperationType.cut:
        _cutPower = v;
      case OperationType.fill:
        _fillPower = v;
      case OperationType.skip:
        return;
    }
    notifyListeners();
  }

  SpeedTextController speedCtrlFor(OperationType op) => switch (op) {
        OperationType.engrave => engraveSpeedCtrl,
        OperationType.cut => cutSpeedCtrl,
        _ => fillSpeedCtrl,
      };

  /// The field's value in mm/min, or null when invalid / out of range.
  static int? parseSpeed(SpeedTextController ctrl) {
    final mmS = ctrl.mmS;
    if (mmS == null) return null;
    final v = (mmS * 60).round();
    if (v < _kSpeedMin || v > _kSpeedMax) return null;
    return v;
  }

  bool get isValid =>
      parseSpeed(engraveSpeedCtrl) != null &&
      parseSpeed(cutSpeedCtrl) != null &&
      parseSpeed(fillSpeedCtrl) != null;

  /// Clamp bounds and fallbacks copied 1:1 from the original dialog.
  LaserSettings result(LaserSettings fallback) {
    final spot = double.tryParse(spotCtrl.text.replaceAll(',', '.')) ??
        fallback.laserSpotSize;
    final sMax = int.tryParse(sMaxCtrl.text.trim()) ?? fallback.sMax;
    return LaserSettings(
      laserMode: _laserMode,
      sMax: sMax.clamp(1, 100000),
      laserSpotSize: spot.clamp(0.01, 10.0),
      engravePower: _engravePower.round(),
      engraveSpeed: (parseSpeed(engraveSpeedCtrl) ?? fallback.engraveSpeed)
          .clamp(_kSpeedMin, _kSpeedMax),
      cutPower: _cutPower.round(),
      cutSpeed: (parseSpeed(cutSpeedCtrl) ?? fallback.cutSpeed)
          .clamp(_kSpeedMin, _kSpeedMax),
      fillPower: _fillPower.round(),
      fillSpeed: (parseSpeed(fillSpeedCtrl) ?? fallback.fillSpeed)
          .clamp(_kSpeedMin, _kSpeedMax),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }
}

/// LASER and DEFAULTS sections of the Machine Settings dialog.
class LaserSettingsSection extends StatelessWidget {
  final LaserSettingsForm form;

  const LaserSettingsSection({super.key, required this.form});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        settingsSectionHeader('LASER', cs),
        _laserModeSelector(cs),
        const SizedBox(height: 14),
        numericSettingRow(
          'Max laser power (S max)', form.sMaxCtrl,
          cs: cs, width: 70, decimal: false,
          hint: 'Must match parameter \$30 in GRBL controller',
        ),
        const SizedBox(height: 14),
        numericSettingRow(
          'Laser spot size', form.spotCtrl,
          cs: cs, width: 64, decimal: true, unit: 'mm',
        ),
        const SizedBox(height: 20),
        settingsSectionHeader('DEFAULTS', cs),
        settingsGroupBox(cs, [
          _defaultRow(OperationType.cut, cs),
          const SizedBox(height: 10),
          _defaultRow(OperationType.fill, cs),
          const SizedBox(height: 10),
          _defaultRow(OperationType.engrave, cs),
        ]),
      ],
    );
  }

  Widget _laserModeSelector(ColorScheme cs) => Row(
        children: LaserMode.values.map((m) {
          final sel = m == form.laserMode;
          return Expanded(
            child: GestureDetector(
              onTap: () => form.laserMode = m,
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

  Widget _defaultRow(OperationType type, ColorScheme cs) {
    final power = form.powerFor(type);
    final speedCtrl = form.speedCtrlFor(type);
    final color = type.color;
    final valid = LaserSettingsForm.parseSpeed(speedCtrl) != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        settingsOpTypeHeader(type, cs, bottomPadding: 4),
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
                  onChanged: (v) => form.setPower(type, v),
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
            steppedNumberField(
              ctrl: speedCtrl,
              color: color,
              valid: valid,
              width: 56,
              decimal: speedCtrl.unit == SpeedUnit.mmPerSec,
              cs: cs,
              unit: speedCtrl.unit.label,
              onDecrement: () => _nudgeSpeed(speedCtrl, -1),
              onIncrement: () => _nudgeSpeed(speedCtrl, 1),
            ),
          ],
        ),
      ],
    );
  }

  /// One step is 1 mm/s or 100 mm/min, depending on the display unit.
  static void _nudgeSpeed(SpeedTextController ctrl, int dir) => ctrl.nudge(
        dir * (ctrl.unit == SpeedUnit.mmPerSec ? 1.0 : 100.0),
        _kSpeedMin / 60.0,
        _kSpeedMax / 60.0,
      );
}
