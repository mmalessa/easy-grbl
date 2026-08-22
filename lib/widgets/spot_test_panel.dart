import 'package:flutter/material.dart';
import '../models/spot_test_config.dart';
import 'test_panel_common.dart';

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
    return TestPanelScaffold(
      icon: Icons.grid_on,
      title: 'Spot Size Test',
      onClose: onClose,
      children: [
        const TestPanelLabel('Power'),
        const SizedBox(height: 4),
        TestPanelPowerSlider(
          value: config.powerPercent,
          onChanged: (v) => onChanged(config.copyWith(powerPercent: v)),
        ),
        const SizedBox(height: 12),
        const TestPanelLabel('Speed (mm/min)'),
        const SizedBox(height: 4),
        TestPanelSpeedStepper(
          value: config.speedMmMin,
          onChanged: (v) => onChanged(config.copyWith(speedMmMin: v)),
        ),
        const SizedBox(height: 16),
        const TestPanelInfoRow('Square', '9 × 9 mm'),
        TestPanelInfoRow('Laser spot', '${spotSize.toStringAsFixed(2)} mm'),
        const SizedBox(height: 8),
        _legend(cs),
      ],
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
}
