import 'package:flutter/material.dart';
import '../models/operation_type.dart';
import 'icon_stepper_button.dart';

// Form-row builders shared by the Machine Settings dialog and the per-mode
// settings sections.

Widget settingsSectionHeader(String title, ColorScheme cs) => Padding(
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

Widget settingsFieldLabel(String text, ColorScheme cs) => Text(
      text,
      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
    );

Widget settingsOpTypeHeader(OperationType type, ColorScheme cs,
        {required double bottomPadding}) =>
    Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Text(
        type.label,
        style: TextStyle(
            color: type.color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5),
      ),
    );

/// A -/+ stepper around a compact [TextField] — the shape shared by the
/// Mill spindle/feed default fields and the Laser speed default field.
/// [onDecrement]/[onIncrement] own the actual parse/clamp/
/// format logic (it differs per field: int vs. double, different steps).
Widget steppedNumberField({
  required TextEditingController ctrl,
  required Color color,
  required bool valid,
  required double width,
  required bool decimal,
  required VoidCallback onDecrement,
  required VoidCallback onIncrement,
  required ColorScheme cs,
  String? unit,
}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconStepperButton(
        icon: Icons.remove,
        color: color,
        width: 26,
        height: 32,
        activeAlpha: 0.15,
        onTap: onDecrement,
      ),
      const SizedBox(width: 2),
      SizedBox(
        width: width,
        child: TextField(
          controller: ctrl,
          style: TextStyle(
              color: valid ? cs.onSurface : cs.error,
              fontSize: 12,
              fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
          decoration: compactFieldDecoration(valid, cs),
          keyboardType: decimal
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.number,
        ),
      ),
      const SizedBox(width: 2),
      IconStepperButton(
        icon: Icons.add,
        color: color,
        width: 26,
        height: 32,
        activeAlpha: 0.15,
        onTap: onIncrement,
      ),
      if (unit != null) ...[
        const SizedBox(width: 4),
        Text(unit, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
      ],
    ],
  );
}

InputDecoration compactFieldDecoration(bool valid, ColorScheme cs) =>
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

/// A field-label (optionally with a hint subtitle, in which case the
/// label column expands) + numeric field + optional trailing unit —
/// the shape shared by every plain numeric setting row in Machine Settings.
Widget numericSettingRow(
  String label,
  TextEditingController ctrl, {
  required ColorScheme cs,
  required double width,
  required bool decimal,
  String? hint,
  String? unit,
  bool isValid = true,
}) {
  final labelWidget = hint == null
      ? settingsFieldLabel(label, cs)
      : Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              settingsFieldLabel(label, cs),
              const SizedBox(height: 2),
              Text(hint,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10)),
            ],
          ),
        );
  return Row(
    children: [
      labelWidget,
      hint == null ? const Spacer() : const SizedBox(width: 12),
      numericField(ctrl, width: width, decimal: decimal, cs: cs, isValid: isValid),
      if (unit != null) ...[
        const SizedBox(width: 6),
        Text(unit, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
      ],
    ],
  );
}

Widget numericField(TextEditingController ctrl,
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

int? parsePositiveInt(TextEditingController ctrl) {
  final v = int.tryParse(ctrl.text.trim());
  if (v == null || v <= 0) return null;
  return v;
}

double? parsePositiveDouble(TextEditingController ctrl) {
  final v = double.tryParse(ctrl.text.replaceAll(',', '.'));
  if (v == null || v <= 0) return null;
  return v;
}

/// The bordered box that groups the per-operation default rows.
Widget settingsGroupBox(ColorScheme cs, List<Widget> children) => Container(
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
        children: children,
      ),
    );
