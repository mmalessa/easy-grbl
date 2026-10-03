import 'package:flutter/material.dart';
import '../../../models/operation_type.dart';
import '../../../models/speed_unit.dart';
import '../../../widgets/settings_form_fields.dart';
import '../mill_settings.dart';

/// Editable state of the mill part of Machine Settings. Notifies on every
/// change so the dialog can re-validate.
class MillSettingsForm extends ChangeNotifier {
  MillSettingsForm(MillSettings s, [SpeedUnit unit = SpeedUnit.mmPerSec])
      : maxSpindleSpeedCtrl = TextEditingController(text: '${s.maxSpindleSpeed}'),
        maxFeedRateCtrl = SpeedTextController(s.maxFeedRate, unit),
        toolDiamCtrl = TextEditingController(text: s.toolDiameter.toStringAsFixed(3)),
        bladeAngleCtrl = TextEditingController(text: s.bladeAngle.toStringAsFixed(1)),
        safeHeightCtrl = TextEditingController(text: s.safeHeight.toStringAsFixed(1)),
        travelFeedRateCtrl = SpeedTextController(s.travelFeedRate, unit),
        engraveSpindleCtrl = TextEditingController(text: '${s.engraveSpindleSpeed}'),
        engraveFeedCtrl = SpeedTextController(s.engraveFeedRate, unit),
        cutSpindleCtrl = TextEditingController(text: '${s.cutSpindleSpeed}'),
        cutFeedCtrl = SpeedTextController(s.cutFeedRate, unit),
        fillSpindleCtrl = TextEditingController(text: '${s.fillSpindleSpeed}'),
        fillFeedCtrl = SpeedTextController(s.fillFeedRate, unit) {
    for (final c in _controllers) {
      c.addListener(notifyListeners);
    }
  }

  final TextEditingController maxSpindleSpeedCtrl;
  final SpeedTextController maxFeedRateCtrl;
  final TextEditingController toolDiamCtrl;
  final TextEditingController bladeAngleCtrl;
  final TextEditingController safeHeightCtrl;
  final SpeedTextController travelFeedRateCtrl;
  final TextEditingController engraveSpindleCtrl;
  final SpeedTextController engraveFeedCtrl;
  final TextEditingController cutSpindleCtrl;
  final SpeedTextController cutFeedCtrl;
  final TextEditingController fillSpindleCtrl;
  final SpeedTextController fillFeedCtrl;

  List<TextEditingController> get _controllers => [
        maxSpindleSpeedCtrl, maxFeedRateCtrl, toolDiamCtrl, bladeAngleCtrl,
        safeHeightCtrl, travelFeedRateCtrl, engraveSpindleCtrl, engraveFeedCtrl,
        cutSpindleCtrl, cutFeedCtrl, fillSpindleCtrl, fillFeedCtrl,
      ];

  List<SpeedTextController> get _speedCtrls => [
        maxFeedRateCtrl, travelFeedRateCtrl, engraveFeedCtrl, cutFeedCtrl,
        fillFeedCtrl,
      ];

  SpeedUnit get speedUnit => maxFeedRateCtrl.unit;
  set speedUnit(SpeedUnit u) {
    for (final c in _speedCtrls) {
      c.unit = u;
    }
  }

  bool get isValid =>
      parsePositiveInt(maxSpindleSpeedCtrl) != null &&
      maxFeedRateCtrl.mmS != null &&
      parsePositiveDouble(toolDiamCtrl) != null &&
      parsePositiveDouble(bladeAngleCtrl) != null &&
      parsePositiveDouble(safeHeightCtrl) != null &&
      travelFeedRateCtrl.mmS != null &&
      parsePositiveInt(cutSpindleCtrl) != null &&
      cutFeedCtrl.mmS != null &&
      parsePositiveInt(fillSpindleCtrl) != null &&
      fillFeedCtrl.mmS != null &&
      parsePositiveInt(engraveSpindleCtrl) != null &&
      engraveFeedCtrl.mmS != null;

  /// Clamp bounds and fallbacks copied 1:1 from the original dialog.
  MillSettings result(MillSettings f) => MillSettings(
        maxSpindleSpeed: (parsePositiveInt(maxSpindleSpeedCtrl) ?? f.maxSpindleSpeed).clamp(1, 1000000),
        maxFeedRate: (maxFeedRateCtrl.mmS ?? f.maxFeedRate).clamp(0.1, 100000.0),
        toolDiameter: (parsePositiveDouble(toolDiamCtrl) ?? f.toolDiameter).clamp(0.1, 100.0),
        bladeAngle: (parsePositiveDouble(bladeAngleCtrl) ?? f.bladeAngle).clamp(1.0, 180.0),
        safeHeight: (parsePositiveDouble(safeHeightCtrl) ?? f.safeHeight).clamp(0.1, 500.0),
        travelFeedRate: (travelFeedRateCtrl.mmS ?? f.travelFeedRate).clamp(1.0, 100000.0),
        engraveSpindleSpeed: (parsePositiveInt(engraveSpindleCtrl) ?? f.engraveSpindleSpeed).clamp(1, 1000000),
        engraveFeedRate: (engraveFeedCtrl.mmS ?? f.engraveFeedRate).clamp(0.1, 10000.0),
        cutSpindleSpeed: (parsePositiveInt(cutSpindleCtrl) ?? f.cutSpindleSpeed).clamp(1, 1000000),
        cutFeedRate: (cutFeedCtrl.mmS ?? f.cutFeedRate).clamp(0.1, 10000.0),
        fillSpindleSpeed: (parsePositiveInt(fillSpindleCtrl) ?? f.fillSpindleSpeed).clamp(1, 1000000),
        fillFeedRate: (fillFeedCtrl.mmS ?? f.fillFeedRate).clamp(0.1, 10000.0),
      );

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }
}

/// MILL and DEFAULTS sections of the Machine Settings dialog.
class MillSettingsSection extends StatelessWidget {
  final MillSettingsForm form;

  const MillSettingsSection({super.key, required this.form});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        settingsSectionHeader('MILL', cs),
        numericSettingRow('Max spindle speed', form.maxSpindleSpeedCtrl,
            cs: cs, width: 80, decimal: false, unit: 'RPM',
            isValid: parsePositiveInt(form.maxSpindleSpeedCtrl) != null),
        const SizedBox(height: 14),
        numericSettingRow('Max feed rate', form.maxFeedRateCtrl,
            cs: cs, width: 80, decimal: true, unit: form.speedUnit.label,
            isValid: form.maxFeedRateCtrl.mmS != null),
        const SizedBox(height: 14),
        numericSettingRow('Tool diameter', form.toolDiamCtrl,
            cs: cs, width: 72, decimal: true, unit: 'mm',
            hint: 'Diameter of the cutting bit at its widest point',
            isValid: parsePositiveDouble(form.toolDiamCtrl) != null),
        const SizedBox(height: 14),
        numericSettingRow('Included angle', form.bladeAngleCtrl,
            cs: cs, width: 72, decimal: true, unit: '°',
            hint: 'Between the two cutting edges',
            isValid: parsePositiveDouble(form.bladeAngleCtrl) != null),
        const SizedBox(height: 14),
        numericSettingRow('Safe height', form.safeHeightCtrl,
            cs: cs, width: 72, decimal: true, unit: 'mm',
            hint: 'Z clearance for rapid moves above the material',
            isValid: parsePositiveDouble(form.safeHeightCtrl) != null),
        const SizedBox(height: 14),
        numericSettingRow('Travel feed rate', form.travelFeedRateCtrl,
            cs: cs, width: 72, decimal: true, unit: form.speedUnit.label,
            hint: 'Speed for non-cutting moves (retract / travel / plunge)',
            isValid: form.travelFeedRateCtrl.mmS != null),
        const SizedBox(height: 20),
        settingsSectionHeader('DEFAULTS', cs),
        settingsGroupBox(cs, [
          _millDefaultRow(OperationType.cut, form.cutSpindleCtrl, form.cutFeedCtrl, cs),
          const SizedBox(height: 10),
          _millDefaultRow(OperationType.fill, form.fillSpindleCtrl, form.fillFeedCtrl, cs),
          const SizedBox(height: 10),
          _millDefaultRow(OperationType.engrave, form.engraveSpindleCtrl, form.engraveFeedCtrl, cs),
        ]),
      ],
    );
  }

  Widget _millDefaultRow(OperationType type,
      TextEditingController spindleCtrl, SpeedTextController feedCtrl,
      ColorScheme cs) {
    final color = type.color;
    final spindleOk = parsePositiveInt(spindleCtrl) != null;
    final feedOk = feedCtrl.mmS != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        settingsOpTypeHeader(type, cs, bottomPadding: 6),
        Row(
          children: [
            Text('Spindle speed',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
            const SizedBox(width: 4),
            steppedNumberField(
              ctrl: spindleCtrl,
              color: color,
              valid: spindleOk,
              width: 60,
              decimal: false,
              cs: cs,
              unit: 'RPM',
              onDecrement: () {
                final v = int.tryParse(spindleCtrl.text.trim()) ?? 1000;
                spindleCtrl.text = '${(v - 1000).clamp(100, 1000000)}';
              },
              onIncrement: () {
                final v = int.tryParse(spindleCtrl.text.trim()) ?? 1000;
                spindleCtrl.text = '${(v + 1000).clamp(100, 1000000)}';
              },
            ),
            const Spacer(),
            Text('Feed rate',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
            const SizedBox(width: 4),
            steppedNumberField(
              ctrl: feedCtrl,
              color: color,
              valid: feedOk,
              width: 52,
              decimal: feedCtrl.unit == SpeedUnit.mmPerSec,
              cs: cs,
              unit: feedCtrl.unit.label,
              // One step is 5 mm/s or 300 mm/min, depending on the unit.
              onDecrement: () => feedCtrl.nudge(
                  feedCtrl.unit == SpeedUnit.mmPerSec ? -5.0 : -300.0,
                  0.1, 10000.0),
              onIncrement: () => feedCtrl.nudge(
                  feedCtrl.unit == SpeedUnit.mmPerSec ? 5.0 : 300.0,
                  0.1, 10000.0),
            ),
          ],
        ),
      ],
    );
  }
}
