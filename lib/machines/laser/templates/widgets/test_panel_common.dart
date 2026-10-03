import 'package:flutter/material.dart';
import '../../../../models/speed_unit.dart';
import '../../../../widgets/icon_stepper_button.dart';

/// Shared chrome for the Focus/Kerf/Spot test panels: an icon+title header
/// with a close button, a divider, and a scrollable body.
class TestPanelScaffold extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onClose;
  final List<Widget> children;

  const TestPanelScaffold({
    super.key,
    required this.icon,
    required this.title,
    required this.onClose,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(cs),
        Divider(height: 1, color: cs.outlineVariant),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 12, color: cs.onSurface),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 14),
            onPressed: onClose,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: cs.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class TestPanelLabel extends StatelessWidget {
  final String text;
  const TestPanelLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text,
      style:
          TextStyle(fontSize: 10, color: cs.onSurfaceVariant, letterSpacing: 0.5),
    );
  }
}

class TestPanelInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const TestPanelInfoRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          TestPanelLabel(label),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurface),
          ),
        ],
      ),
    );
  }
}

/// Percent power slider with the value displayed above the track.
class TestPanelPowerSlider extends StatelessWidget {
  final int value;
  final int min;
  final int divisions;
  final ValueChanged<int> onChanged;

  const TestPanelPowerSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.divisions = 99,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = cs.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Spacer(),
            Text(
              '$value%',
              style:
                  TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.15),
            inactiveTrackColor: cs.surfaceContainerHighest,
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: 100,
            divisions: divisions,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ],
    );
  }
}

/// Speed +/- stepper; [value] and [onChanged] are in mm/min, clamped to
/// [100, 30000], and the value is shown in [unit]. One step is 100 mm/min
/// or 1 mm/s.
class TestPanelSpeedStepper extends StatelessWidget {
  final int value;
  final SpeedUnit unit;
  final ValueChanged<int> onChanged;

  const TestPanelSpeedStepper({
    super.key,
    required this.value,
    required this.unit,
    required this.onChanged,
  });

  int _stepped(int dir) {
    if (unit == SpeedUnit.mmPerMin) return (value + dir * 100).clamp(100, 30000);
    final mmS = (value / 60.0).roundToDouble() + dir;
    return (mmS * 60).round().clamp(100, 30000);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        IconStepperButton(
          icon: Icons.remove,
          color: cs.primary,
          width: 32,
          height: 28,
          iconSize: 14,
          onTap: () => onChanged(_stepped(-1)),
        ),
        Expanded(
          child: Text(
            unit.format(unit.fromMmS(value / 60.0)),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface),
          ),
        ),
        IconStepperButton(
          icon: Icons.add,
          color: cs.primary,
          width: 32,
          height: 28,
          iconSize: 14,
          onTap: () => onChanged(_stepped(1)),
        ),
      ],
    );
  }
}
