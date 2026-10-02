import 'package:flutter/material.dart';
import '../../../models/operation_type.dart';
import '../../../widgets/settings_form_fields.dart';
import '../mill_settings.dart';

/// Editable state of the mill part of Machine Settings. Notifies on every
/// change so the dialog can re-validate.
class MillSettingsForm extends ChangeNotifier {
  MillSettingsForm(MillSettings s)
      : maxSpindleSpeedCtrl = TextEditingController(text: '${s.maxSpindleSpeed}'),
        maxFeedRateCtrl = TextEditingController(text: s.maxFeedRate.toStringAsFixed(1)),
        toolDiamCtrl = TextEditingController(text: s.toolDiameter.toStringAsFixed(3)),
        bladeAngleCtrl = TextEditingController(text: s.bladeAngle.toStringAsFixed(1)),
        safeHeightCtrl = TextEditingController(text: s.safeHeight.toStringAsFixed(1)),
        travelFeedRateCtrl = TextEditingController(text: s.travelFeedRate.toStringAsFixed(1)),
        engraveSpindleCtrl = TextEditingController(text: '${s.engraveSpindleSpeed}'),
        engraveFeedCtrl = TextEditingController(text: s.engraveFeedRate.toStringAsFixed(1)),
        cutSpindleCtrl = TextEditingController(text: '${s.cutSpindleSpeed}'),
        cutFeedCtrl = TextEditingController(text: s.cutFeedRate.toStringAsFixed(1)),
        fillSpindleCtrl = TextEditingController(text: '${s.fillSpindleSpeed}'),
        fillFeedCtrl = TextEditingController(text: s.fillFeedRate.toStringAsFixed(1)) {
    for (final c in _controllers) {
      c.addListener(notifyListeners);
    }
  }

  final TextEditingController maxSpindleSpeedCtrl;
  final TextEditingController maxFeedRateCtrl;
  final TextEditingController toolDiamCtrl;
  final TextEditingController bladeAngleCtrl;
  final TextEditingController safeHeightCtrl;
  final TextEditingController travelFeedRateCtrl;
  final TextEditingController engraveSpindleCtrl;
  final TextEditingController engraveFeedCtrl;
  final TextEditingController cutSpindleCtrl;
  final TextEditingController cutFeedCtrl;
  final TextEditingController fillSpindleCtrl;
  final TextEditingController fillFeedCtrl;

  List<TextEditingController> get _controllers => [
        maxSpindleSpeedCtrl, maxFeedRateCtrl, toolDiamCtrl, bladeAngleCtrl,
        safeHeightCtrl, travelFeedRateCtrl, engraveSpindleCtrl, engraveFeedCtrl,
        cutSpindleCtrl, cutFeedCtrl, fillSpindleCtrl, fillFeedCtrl,
      ];

  bool get isValid =>
      parsePositiveInt(maxSpindleSpeedCtrl) != null &&
      parsePositiveDouble(maxFeedRateCtrl) != null &&
      parsePositiveDouble(toolDiamCtrl) != null &&
      parsePositiveDouble(bladeAngleCtrl) != null &&
      parsePositiveDouble(safeHeightCtrl) != null &&
      parsePositiveDouble(travelFeedRateCtrl) != null &&
      parsePositiveInt(cutSpindleCtrl) != null &&
      parsePositiveDouble(cutFeedCtrl) != null &&
      parsePositiveInt(fillSpindleCtrl) != null &&
      parsePositiveDouble(fillFeedCtrl) != null &&
      parsePositiveInt(engraveSpindleCtrl) != null &&
      parsePositiveDouble(engraveFeedCtrl) != null;

  /// Clamp bounds and fallbacks copied 1:1 from the original dialog.
  MillSettings result(MillSettings f) => MillSettings(
        maxSpindleSpeed: (parsePositiveInt(maxSpindleSpeedCtrl) ?? f.maxSpindleSpeed).clamp(1, 1000000),
        maxFeedRate: (parsePositiveDouble(maxFeedRateCtrl) ?? f.maxFeedRate).clamp(0.1, 100000.0),
        toolDiameter: (parsePositiveDouble(toolDiamCtrl) ?? f.toolDiameter).clamp(0.1, 100.0),
        bladeAngle: (parsePositiveDouble(bladeAngleCtrl) ?? f.bladeAngle).clamp(1.0, 180.0),
        safeHeight: (parsePositiveDouble(safeHeightCtrl) ?? f.safeHeight).clamp(0.1, 500.0),
        travelFeedRate: (parsePositiveDouble(travelFeedRateCtrl) ?? f.travelFeedRate).clamp(1.0, 100000.0),
        engraveSpindleSpeed: (parsePositiveInt(engraveSpindleCtrl) ?? f.engraveSpindleSpeed).clamp(1, 1000000),
        engraveFeedRate: (parsePositiveDouble(engraveFeedCtrl) ?? f.engraveFeedRate).clamp(0.1, 10000.0),
        cutSpindleSpeed: (parsePositiveInt(cutSpindleCtrl) ?? f.cutSpindleSpeed).clamp(1, 1000000),
        cutFeedRate: (parsePositiveDouble(cutFeedCtrl) ?? f.cutFeedRate).clamp(0.1, 10000.0),
        fillSpindleSpeed: (parsePositiveInt(fillSpindleCtrl) ?? f.fillSpindleSpeed).clamp(1, 1000000),
        fillFeedRate: (parsePositiveDouble(fillFeedCtrl) ?? f.fillFeedRate).clamp(0.1, 10000.0),
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
            cs: cs, width: 80, decimal: true, unit: 'mm/s',
            isValid: parsePositiveDouble(form.maxFeedRateCtrl) != null),
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
            cs: cs, width: 72, decimal: true, unit: 'mm/s',
            hint: 'Speed for non-cutting moves (retract / travel / plunge)',
            isValid: parsePositiveDouble(form.travelFeedRateCtrl) != null),
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
      TextEditingController spindleCtrl, TextEditingController feedCtrl,
      ColorScheme cs) {
    final color = type.color;
    final spindleOk = parsePositiveInt(spindleCtrl) != null;
    final feedOk = parsePositiveDouble(feedCtrl) != null;
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
              decimal: true,
              cs: cs,
              unit: 'mm/s',
              onDecrement: () {
                final v =
                    double.tryParse(feedCtrl.text.replaceAll(',', '.')) ?? 5.0;
                feedCtrl.text =
                    ((v - 5.0).clamp(0.1, 10000.0)).toStringAsFixed(1);
              },
              onIncrement: () {
                final v =
                    double.tryParse(feedCtrl.text.replaceAll(',', '.')) ?? 5.0;
                feedCtrl.text =
                    ((v + 5.0).clamp(0.1, 10000.0)).toStringAsFixed(1);
              },
            ),
          ],
        ),
      ],
    );
  }
}
