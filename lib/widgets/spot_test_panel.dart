import 'package:flutter/material.dart';
import '../models/spot_test_config.dart';

class SpotTestPanel extends StatelessWidget {
  final SpotTestConfig config;
  final double spotSize;
  final ValueChanged<SpotTestConfig> onChanged;
  final VoidCallback onClose;

  const SpotTestPanel({
    super.key,
    required this.config,
    required this.spotSize,
    required this.onChanged,
    required this.onClose,
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
              children: [
                _label('Power', cs),
                const SizedBox(height: 4),
                _powerSlider(cs),
                const SizedBox(height: 12),
                _label('Speed (mm/min)', cs),
                const SizedBox(height: 4),
                _speedStepper(cs),
                const SizedBox(height: 16),
                _infoRow('Square', '9 × 9 mm', cs),
                _infoRow('Laser spot', '${spotSize.toStringAsFixed(2)} mm', cs),
                const SizedBox(height: 8),
                _legend(cs),
              ],
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
          Icon(Icons.grid_on, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            'Spot Size Test',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: cs.onSurface),
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

  Widget _label(String text, ColorScheme cs) {
    return Text(
      text,
      style: TextStyle(
          fontSize: 10, color: cs.onSurfaceVariant, letterSpacing: 0.5),
    );
  }

  Widget _infoRow(String label, String value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          _label(label, cs),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _legend(ColorScheme cs) {
    final bands = [
      ('Top', 'spot size + 0.1 mm', Colors.red.shade300),
      ('Middle', 'spot size (exact)', Colors.green.shade400),
      ('Bottom', 'spot size − 0.1 mm', Colors.blue.shade300),
    ];
    return Column(
      children: bands.map((b) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: b.$3,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${b.$1} — ${b.$2}',
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _powerSlider(ColorScheme cs) {
    final color = cs.primary;
    final pct = config.powerPercent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Spacer(),
            Text(
              '$pct%',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color),
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
            value: pct.toDouble(),
            min: 1,
            max: 100,
            divisions: 99,
            onChanged: (v) =>
                onChanged(config.copyWith(powerPercent: v.round())),
          ),
        ),
      ],
    );
  }

  Widget _speedStepper(ColorScheme cs) {
    return Row(
      children: [
        _speedBtn(Icons.remove, () {
          final v = (config.speedMmMin - 100).clamp(100, 30000);
          onChanged(config.copyWith(speedMmMin: v));
        }, cs),
        Expanded(
          child: Text(
            '${config.speedMmMin}',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurface),
          ),
        ),
        _speedBtn(Icons.add, () {
          final v = (config.speedMmMin + 100).clamp(100, 30000);
          onChanged(config.copyWith(speedMmMin: v));
        }, cs),
      ],
    );
  }

  Widget _speedBtn(IconData icon, VoidCallback? onTap, ColorScheme cs) {
    return SizedBox(
      width: 32,
      height: 28,
      child: Material(
        color: onTap != null
            ? cs.primary.withValues(alpha: 0.12)
            : cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Icon(
            icon,
            size: 14,
            color: onTap != null ? cs.primary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
